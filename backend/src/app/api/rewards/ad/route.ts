import { handle, json, auth, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
/** OPTIONAL extra: after watching a rewarded ad the app may request a free cosmetic. No essential feature depends on this.
 *  The claim is client-reported (AdMob server-side verification is a documented TODO) so it is capped per day and only grants cosmetics. */
export const POST = handle(async (r) => {
  const c = await auth(r);
  const max = Number((await q<{ value: unknown }>("SELECT value FROM app_config WHERE key='rewards.max_ad_claims_per_day'"))[0]?.value ?? 3);
  const used = (await q<{ n: number }>("SELECT count(*)::int AS n FROM rewarded_ad_claims WHERE user_id=$1 AND day=CURRENT_DATE", [c.sub]))[0].n;
  if (used >= max) throw new HttpError(429, "daily_cap_reached");
  const item = (await q<{ id: string }>("SELECT id FROM cosmetic_items WHERE active AND kind IN ('frame','cover','name_color','effect') AND NOT behavioral AND id NOT IN (SELECT item_id FROM user_items WHERE user_id=$1) ORDER BY id LIMIT 1", [c.sub]))[0];
  await q("INSERT INTO rewarded_ad_claims(user_id,item_id,verified) VALUES ($1,$2,false)", [c.sub, item?.id ?? null]);
  if (item) await q("INSERT INTO user_items(user_id,item_id,source) VALUES ($1,$2,'rewarded_ad') ON CONFLICT DO NOTHING", [c.sub, item.id]);
  return json({ item_id: item?.id ?? null, remaining_today: max - used - 1 });
});
