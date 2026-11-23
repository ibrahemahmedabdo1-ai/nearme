import { handle, json, auth, body, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
const SLOTS: Record<string, string> = { frame: "frame", cover: "cover", name_color: "name_color", effect: "effect" };
export const POST = handle(async (r) => {
  const c = await auth(r);
  const b = await body(r, x => { if (!(x.slot in SLOTS)) throw new Error("invalid_slot"); return { slot: x.slot as string, item: x.item_id === null ? null : String(x.item_id) }; });
  if (b.item !== null && !(await q("SELECT 1 FROM user_items ui JOIN cosmetic_items ci ON ci.id=ui.item_id WHERE ui.user_id=$1 AND ui.item_id=$2 AND ci.kind=$3", [c.sub, b.item, SLOTS[b.slot]])).length) throw new HttpError(403, "item_not_owned");
  await q("UPDATE users SET equipped = CASE WHEN $3::text IS NULL THEN equipped - $2::text ELSE jsonb_set(equipped, ARRAY[$2::text], to_jsonb($3::text)) END WHERE id=$1", [c.sub, b.slot, b.item]);
  return json({ ok: true });
});
