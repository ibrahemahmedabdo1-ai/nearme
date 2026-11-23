import { handle, json, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
import { env } from "@/lib/env";
import { timingSafeEqual } from "node:crypto";
/** Data retention: expired temporary messages, verification evidence past its deletion date, stale tokens/sessions/typing rows. Cron-secret protected. */
export const GET = handle(async (r) => {
  const given = Buffer.from(r.headers.get("authorization")?.replace(/^Bearer /, "") ?? ""), want = Buffer.from(env("CRON_SECRET"));
  if (given.length !== want.length || !timingSafeEqual(given, want)) throw new HttpError(401, "unauthorized");
  const msgs = await q("DELETE FROM messages WHERE expires_at IS NOT NULL AND expires_at < now() RETURNING id");
  const ev = await q("UPDATE verifications SET evidence_storage_key=NULL,evidence_delete_after=NULL WHERE evidence_delete_after < now() AND evidence_storage_key IS NOT NULL RETURNING id");
  const ses = await q("DELETE FROM sessions WHERE expires_at < now() - interval '30 days' RETURNING id");
  const ty = await q("DELETE FROM typing_state WHERE until < now() RETURNING 1");
  return json({ messages_deleted: msgs.length, evidence_cleared: ev.length, sessions_deleted: ses.length, typing_cleared: ty.length });
});
