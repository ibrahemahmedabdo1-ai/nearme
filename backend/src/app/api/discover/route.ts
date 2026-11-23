import { handle, json, auth, guardMode } from "@/lib/http";
import { q } from "@/lib/db";
import { RADIUS_OPTIONS, approxDistance, haversineKm, compatibility, DEFAULT_RADIUS_KM, DEFAULT_WEIGHTS, type Weights } from "@/domain/matching";
import { NextRequest } from "next/server";
export const GET = handle(async (r: NextRequest) => {
  const c = await auth(r); await guardMode("read", c);
  const p = new URL(r.url).searchParams;
  const rp = p.get("radius");   // "all" => no limit
  const radius = rp === "all" ? null : rp ? Number(rp) : DEFAULT_RADIUS_KM;
  if (radius !== null && !(RADIUS_OPTIONS as readonly number[]).includes(radius)) return json({ error: "invalid_radius" }, 422);
  const me = (await q<any>("SELECT u.lat_cell,u.lon_cell,pr.min_age,pr.max_age,pr.verified_only,(SELECT coalesce(array_agg(i.slug),'{}') FROM user_interests ui JOIN interests i ON i.id=ui.interest_id WHERE ui.user_id=u.id) AS interests FROM users u JOIN preferences pr ON pr.user_id=u.id WHERE u.id=$1", [c.sub]))[0];
  const w = ((await q<{ value: Weights }>("SELECT value FROM app_config WHERE key='matching.weights'"))[0]?.value ?? DEFAULT_WEIGHTS) as Weights;   // Owner-controlled weights
  const rows = await q<any>(
    `SELECT u.id,u.member_code,u.display_name,u.lat_cell,u.lon_cell,u.last_seen_at,(u.boost_until IS NOT NULL AND u.boost_until>now()) AS boosted,u.equipped,
            date_part('year',age(u.birthdate))::int AS age,
            EXISTS(SELECT 1 FROM verifications v WHERE v.user_id=u.id AND v.status='approved') AS verified,
            (SELECT coalesce(array_agg(i.slug),'{}') FROM user_interests ui JOIN interests i ON i.id=ui.interest_id WHERE ui.user_id=u.id) AS interests
     FROM users u
     WHERE u.status='active' AND u.id<>$1 AND (u.hidden_until IS NULL OR u.hidden_until<now()) AND u.role='customer'
       AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.blocker=$1 AND b.blocked=u.id) OR (b.blocker=u.id AND b.blocked=$1))
       AND date_part('year',age(u.birthdate)) BETWEEN $2 AND $3
     LIMIT 300`, [c.sub, me.min_age, me.max_age]);
  const out = rows.map((u: any) => {
    const km = me.lat_cell != null && u.lat_cell != null ? haversineKm([me.lat_cell, me.lon_cell], [u.lat_cell, u.lon_cell]) : null;
    return { u, km };
  }).filter((x: any) => (radius === null || (x.km !== null && x.km <= radius)) && (!me.verified_only || x.u.verified))
    .map(({ u, km }: any) => {
      const cm = compatibility({ interests: me.interests, radiusKm: radius, minAge: me.min_age, maxAge: me.max_age }, { interests: u.interests, distanceKm: km, age: u.age, lastActiveMs: u.last_seen_at ? +new Date(u.last_seen_at) : 0, verified: u.verified }, w);
      return { id: u.id, member_code: u.member_code, name: u.display_name, age: u.age, verified: u.verified, boosted: u.boosted, equipped: u.equipped, distance_km: km === null ? null : approxDistance(km), compatibility: cm.score, reasons: cm.reasons };
    }).sort((a: any, b: any) => Number(b.boosted) - Number(a.boosted) || b.compatibility - a.compatibility).slice(0, 50);
  return json({ radius_km: radius, results: out });   // exact coordinates are never returned
});
