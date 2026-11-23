import { handle, json, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
import { env } from "@/lib/env";
import { getProviders } from "@/providers";
import { timingSafeEqual } from "node:crypto";
/** Publishes approved, due posts. If the platform API is not available the post is marked blocked_no_api_access -- NEVER 'published'. */
export const GET = handle(async (r) => {
  const given = Buffer.from(r.headers.get("authorization")?.replace(/^Bearer /, "") ?? ""), want = Buffer.from(env("CRON_SECRET"));
  if (given.length !== want.length || !timingSafeEqual(given, want)) throw new HttpError(401, "unauthorized");
  const due = await q<any>("UPDATE social_posts SET status='publishing' WHERE id IN (SELECT id FROM social_posts WHERE status='approved' AND (scheduled_at IS NULL OR scheduled_at<=now()) ORDER BY scheduled_at LIMIT 20 FOR UPDATE SKIP LOCKED) RETURNING id,account_id,body,media_key");
  const out = { published: 0, blocked: 0, failed: 0 };
  for (const p of due) {
    const acc = (await q<{ platform: any }>("SELECT platform FROM social_accounts WHERE id=$1 AND status='linked'", [p.account_id]))[0];
    const res = acc ? await getProviders().social.publish(acc.platform, { text: p.body.text, mediaKey: p.media_key ?? undefined }) : ({ ok: false, reason: "provider_error", detail: "account_unlinked" } as const);
    if (res.ok) { await q("UPDATE social_posts SET status='published',published_at=now(),external_post_id=$2 WHERE id=$1", [p.id, res.data.externalId]); out.published++; }
    else if (res.reason === "not_configured") { await q("UPDATE social_posts SET status='blocked_no_api_access',error='platform API not configured' WHERE id=$1", [p.id]); out.blocked++; }
    else { await q("UPDATE social_posts SET status='failed',error=$2 WHERE id=$1", [p.id, String(res.detail ?? "error").slice(0, 300)]); out.failed++; }
  }
  return json(out);
});
