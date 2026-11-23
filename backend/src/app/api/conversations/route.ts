import { handle, json, auth, body, str, guardMode, HttpError, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => {
  const c = await auth(r);
  const rows = await q(`SELECT cv.id,cv.kind,cv.intro_status,cv.initiator,cv.created_at,
      CASE WHEN cv.user_a=$1 THEN cv.user_b ELSE cv.user_a END AS other_id,
      (SELECT display_name FROM users u WHERE u.id = CASE WHEN cv.user_a=$1 THEN cv.user_b ELSE cv.user_a END) AS other_name,
      (SELECT max(sent_at) FROM messages m WHERE m.conversation_id=cv.id) AS last_message_at,
      (SELECT count(*)::int FROM messages m WHERE m.conversation_id=cv.id AND m.sender_id<>$1 AND m.read_at IS NULL AND m.deleted_for_all_at IS NULL) AS unread
    FROM conversations cv WHERE $1 IN (cv.user_a,cv.user_b) AND cv.intro_status<>'rejected'
      AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.blocker=$1 AND b.blocked=CASE WHEN cv.user_a=$1 THEN cv.user_b ELSE cv.user_a END) OR (b.blocked=$1 AND b.blocker=CASE WHEN cv.user_a=$1 THEN cv.user_b ELSE cv.user_a END))
    ORDER BY last_message_at DESC NULLS LAST LIMIT 100`, [c.sub]);
  return json({ conversations: rows });
});
/** Open an introduction request. One conversation per pair exists forever, so a new request can never reset the 3-message limit. */
export const POST = handle(async (r) => {
  const c = await auth(r); await guardMode("send_message", c); rateLimit(r, "intro", 30, 3_600_000, c.sub);
  const { to } = await body(r, x => ({ to: str(x.to_user, "to_user", 36, 36) }));
  if (to === c.sub) throw new HttpError(422, "invalid_target");
  const target = (await q<{ status: string }>("SELECT status FROM users WHERE id=$1 AND role='customer'", [to]))[0];
  if (!target || target.status !== "active") throw new HttpError(404, "not_found");
  if ((await q("SELECT 1 FROM blocks WHERE (blocker=$1 AND blocked=$2) OR (blocker=$2 AND blocked=$1)", [c.sub, to])).length) throw new HttpError(403, "blocked");
  if ((await q("SELECT 1 FROM punishments WHERE user_id=$1 AND kind='message_restriction' AND revoked_at IS NULL AND (ends_at IS NULL OR ends_at>now())", [c.sub])).length) throw new HttpError(403, "messaging_restricted");
  const [lo, hi] = c.sub < to ? [c.sub, to] : [to, c.sub];
  const existing = (await q<{ id: string; intro_status: string }>("SELECT id,intro_status FROM conversations WHERE user_a=$1 AND user_b=$2", [lo, hi]))[0];
  if (existing) return json({ conversation_id: existing.id, intro_status: existing.intro_status, existing: true });
  // Owner-controlled rule for who may send introduction requests
  const rule = String((await q<{ value: unknown }>("SELECT value FROM app_config WHERE key='intro.rule'"))[0]?.value ?? "anyone").replace(/"/g, "");
  if (rule === "verified_only" && !(await q("SELECT 1 FROM verifications WHERE user_id=$1 AND status='approved'", [c.sub])).length) throw new HttpError(403, "verification_required");
  if (rule === "matched_only") throw new HttpError(403, "match_required");
  const row = (await q<{ id: string }>("INSERT INTO conversations(user_a,user_b,kind,intro_status,initiator) VALUES ($1,$2,'intro','pending',$3) RETURNING id", [lo, hi, c.sub]))[0];
  return json({ conversation_id: row.id, intro_status: "pending" }, 201);
});
