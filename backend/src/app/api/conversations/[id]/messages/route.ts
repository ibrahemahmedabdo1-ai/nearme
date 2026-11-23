import { handle, json, auth, body, str, guardMode, HttpError, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
const KINDS = ["text", "image", "gif", "sticker", "file", "location"];
async function loadConv(id: string, me: string) {
  const conv = (await q<any>("SELECT * FROM conversations WHERE id=$1 AND ($2 IN (user_a,user_b))", [id, me]))[0];
  if (!conv) throw new HttpError(404, "not_found");
  return { conv, other: conv.user_a === me ? conv.user_b : conv.user_a };
}
export const GET = handle(async (r, { params }) => {
  const c = await auth(r); const { id } = await params; const { other } = await loadConv(id, c.sub);
  if ((await q("SELECT 1 FROM blocks WHERE (blocker=$1 AND blocked=$2) OR (blocker=$2 AND blocked=$1)", [c.sub, other])).length) throw new HttpError(403, "blocked");
  const since = new URL(r.url).searchParams.get("since");
  const prefs = (await q<{ read_receipts: boolean }>("SELECT read_receipts FROM preferences WHERE user_id=$1", [other]))[0];
  const rows = await q<any>(`SELECT m.id,m.sender_id,m.kind,CASE WHEN m.deleted_for_all_at IS NULL THEN m.body END AS body,m.attachment_id,m.reply_to,m.sent_at,m.delivered_at,m.read_at,m.expires_at,m.deleted_for_all_at,m.pinned,
      (SELECT coalesce(json_agg(json_build_object('user_id',mr.user_id,'emoji',mr.emoji)),'[]') FROM message_reactions mr WHERE mr.message_id=m.id) AS reactions
    FROM messages m WHERE m.conversation_id=$1 AND ($3::timestamptz IS NULL OR m.sent_at>$3::timestamptz)
      AND NOT EXISTS (SELECT 1 FROM message_deletions d WHERE d.message_id=m.id AND d.user_id=$2)
      AND (m.expires_at IS NULL OR m.expires_at>now()) ORDER BY m.sent_at ASC LIMIT 200`, [id, c.sub, since]);
  await q("UPDATE messages SET delivered_at=now() WHERE conversation_id=$1 AND sender_id<>$2 AND delivered_at IS NULL", [id, c.sub]);
  // Respect the other member's read-receipt privacy: hide read_at on messages I sent when they disabled receipts.
  const peer = (await q<any>(`SELECT p.show_online,p.show_last_seen,u.last_seen_at,(SELECT until>now() FROM typing_state t WHERE t.conversation_id=$2 AND t.user_id=$1) AS typing FROM users u JOIN preferences p ON p.user_id=u.id WHERE u.id=$1`, [other, id]))[0];
  const seenMs = peer?.last_seen_at ? +new Date(peer.last_seen_at) : 0;
  const presence = { online: !!peer?.show_online && Date.now() - seenMs < 120_000, last_seen_at: peer?.show_last_seen ? peer.last_seen_at : null, typing: !!peer?.typing };   // privacy settings respected
  return json({ peer: presence, messages: rows.map((m: any) => (m.sender_id === c.sub && prefs && prefs.read_receipts === false ? { ...m, read_at: null } : m)) });
});
export const POST = handle(async (r, { params }) => {
  const c = await auth(r); await guardMode("send_message", c); rateLimit(r, "msg", 120, 60_000, c.sub);
  const { id } = await params;
  const b = await body(r, x => ({ kind: KINDS.includes(x.kind) ? (x.kind as string) : (() => { throw new Error("invalid_kind"); })(), body: x.body == null ? null : str(x.body, "body", 1, 4000), attachment_id: x.attachment_id ?? null, reply_to: x.reply_to ?? null }));
  if (b.kind === "text" && !b.body) throw new HttpError(422, "empty_message");
  const { conv, other } = await loadConv(id, c.sub);
  if ((await q("SELECT 1 FROM blocks WHERE (blocker=$1 AND blocked=$2) OR (blocker=$2 AND blocked=$1)", [c.sub, other])).length) throw new HttpError(403, "blocked");
  if (conv.intro_status === "rejected") throw new HttpError(403, "request_rejected");
  if ((await q("SELECT 1 FROM punishments WHERE user_id=$1 AND kind='message_restriction' AND revoked_at IS NULL AND (ends_at IS NULL OR ends_at>now())", [c.sub])).length) throw new HttpError(403, "messaging_restricted");
  if (b.attachment_id && !(await q("SELECT 1 FROM attachments WHERE id=$1 AND owner_id=$2 AND scan_status='clean'", [b.attachment_id, c.sub])).length) throw new HttpError(422, "attachment_not_ready");
  if (b.kind === "gif") { let h = ""; try { const u = new URL(b.body ?? ""); h = u.protocol === "https:" ? u.hostname : ""; } catch { /* invalid */ } if (!/(^|\.)giphy\.com$/.test(h)) throw new HttpError(422, "invalid_gif_url"); }
  if (b.kind === "sticker" && !(await q("SELECT 1 FROM cosmetic_items WHERE id=$1 AND kind='sticker' AND active", [b.body])).length) throw new HttpError(422, "unknown_sticker");
  if ((b.kind === "image" || b.kind === "file") && !b.attachment_id) throw new HttpError(422, "attachment_required");
  try {   // the DB trigger enforces the pending-intro 3-message limit atomically (race-safe)
    const m = await q("INSERT INTO messages(conversation_id,sender_id,kind,body,attachment_id,reply_to) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id,sent_at", [id, c.sub, b.kind, b.body, b.attachment_id, b.reply_to]);
    return json({ message: m[0] }, 201);
  } catch (e: any) { if (String(e?.message).includes("intro_limit_reached")) throw new HttpError(429, "intro_limit_reached"); throw e; }
});
