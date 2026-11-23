import { handle, json, auth, body, str, HttpError, rateLimit, guardMode } from "@/lib/http";
import { q } from "@/lib/db";
/** Free virtual gifts (no payments). Only between members who have an accepted conversation and no block. */
export const POST = handle(async (r) => {
  const c = await auth(r); await guardMode("write", c); rateLimit(r, "gift", 10, 86_400_000, c.sub);
  const b = await body(r, x => ({ to: str(x.to_user, "to_user", 36, 36), item: str(x.item_id, "item_id", 1, 60) }));
  if (b.to === c.sub) throw new HttpError(422, "invalid_target");
  if (!(await q("SELECT 1 FROM cosmetic_items WHERE id=$1 AND kind='gift' AND active", [b.item])).length) throw new HttpError(422, "unknown_gift");
  const [lo, hi] = c.sub < b.to ? [c.sub, b.to] : [b.to, c.sub];
  if (!(await q("SELECT 1 FROM conversations WHERE user_a=$1 AND user_b=$2 AND intro_status='accepted'", [lo, hi])).length) throw new HttpError(403, "conversation_required");
  if ((await q("SELECT 1 FROM blocks WHERE (blocker=$1 AND blocked=$2) OR (blocker=$2 AND blocked=$1)", [c.sub, b.to])).length) throw new HttpError(403, "blocked");
  const g = (await q<{ id: string }>("INSERT INTO gifts_sent(from_user,to_user,item_id) VALUES ($1,$2,$3) RETURNING id", [c.sub, b.to, b.item]))[0];
  await q("INSERT INTO notifications(user_id,kind,title,data) VALUES ($1,'gift','New gift',$2)", [b.to, JSON.stringify({ gift_id: g.id, item: b.item, from: c.sub })]);
  return json({ gift_id: g.id }, 201);
});
