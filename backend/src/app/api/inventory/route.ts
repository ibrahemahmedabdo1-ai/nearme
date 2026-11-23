import { handle, json, auth } from "@/lib/http";
import { q } from "@/lib/db";
import { awardBehavioralBadges } from "@/lib/badges";
export const GET = handle(async (r) => {
  const c = await auth(r); await awardBehavioralBadges(c.sub);
  const items = await q("SELECT ci.id,ci.kind,ci.name_en,ci.name_ar,ci.payload,ci.animated,ci.behavioral,ui.source,ui.acquired_at FROM user_items ui JOIN cosmetic_items ci ON ci.id=ui.item_id WHERE ui.user_id=$1 ORDER BY ui.acquired_at DESC", [c.sub]);
  const eq = (await q<{ equipped: unknown }>("SELECT equipped FROM users WHERE id=$1", [c.sub]))[0]?.equipped;
  const gifts = await q("SELECT gs.id,gs.item_id,ci.payload,gs.created_at,u.display_name AS from_name FROM gifts_sent gs JOIN cosmetic_items ci ON ci.id=gs.item_id JOIN users u ON u.id=gs.from_user WHERE gs.to_user=$1 ORDER BY gs.created_at DESC LIMIT 50", [c.sub]);
  return json({ items, equipped: eq, gifts_received: gifts });
});
