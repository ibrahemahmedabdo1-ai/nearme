import { handle, json, auth, body, str, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
import { canDeleteForBoth, expiresAt, type TempMode } from "@/domain/messaging";
const ACTIONS = ["read", "delete_me", "delete_all", "react", "pin"];
export const PATCH = handle(async (r, { params }) => {
  const c = await auth(r); const { id, mid } = await params;
  const b = await body(r, x => { if (!ACTIONS.includes(x.action)) throw new Error("invalid_action"); return { action: x.action as string, emoji: x.emoji == null ? null : str(x.emoji, "emoji", 1, 16), pinned: x.pinned !== false }; });
  const m = (await q<any>("SELECT m.* FROM messages m JOIN conversations cv ON cv.id=m.conversation_id WHERE m.id=$1 AND m.conversation_id=$2 AND $3 IN (cv.user_a,cv.user_b)", [mid, id, c.sub]))[0];
  if (!m) throw new HttpError(404, "not_found");
  switch (b.action) {
    case "read": {
      if (m.sender_id === c.sub) throw new HttpError(422, "own_message");
      const mode = ((await q<{ temp_messages: TempMode }>("SELECT temp_messages FROM preferences WHERE user_id=$1", [m.sender_id]))[0]?.temp_messages ?? "off") as TempMode;
      const exp = expiresAt(mode, Date.now());   // temporary messages count down from the moment of reading
      await q("UPDATE messages SET read_at=COALESCE(read_at,now()), expires_at=COALESCE(expires_at, CASE WHEN $2::bigint IS NULL THEN NULL ELSE to_timestamp($2::bigint/1000.0) END) WHERE id=$1", [mid, exp]);
      break; }
    case "delete_me": await q("INSERT INTO message_deletions(message_id,user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING", [mid, c.sub]); break;
    case "delete_all": {
      const win = Number((await q<{ value: unknown }>("SELECT value FROM app_config WHERE key='messages.delete_for_both_minutes'"))[0]?.value ?? 10);
      if (!canDeleteForBoth(+new Date(m.sent_at), m.sender_id, c.sub, win)) throw new HttpError(403, "delete_window_closed");
      await q("UPDATE messages SET deleted_for_all_at=now(), body=NULL WHERE id=$1", [mid]); break; }
    case "react": await q("INSERT INTO message_reactions(message_id,user_id,emoji) VALUES ($1,$2,$3) ON CONFLICT (message_id,user_id) DO UPDATE SET emoji=EXCLUDED.emoji", [mid, c.sub, b.emoji ?? "👍"]); break;
    case "pin": await q("UPDATE messages SET pinned=$2 WHERE id=$1", [mid, b.pinned]); break;
  }
  return json({ ok: true });
});
