import { handle, json, auth, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
/** Profile Boost (free): shown first in discovery for 30 minutes; once per 24h. */
export const POST = handle(async (r) => {
  const c = await auth(r);
  if ((await q("SELECT 1 FROM boosts WHERE user_id=$1 AND started_at>now()-interval '24 hours'", [c.sub])).length) throw new HttpError(429, "boost_cooldown");
  const b = await q<{ ends_at: string }>("INSERT INTO boosts(user_id,ends_at) VALUES ($1, now()+interval '30 minutes') RETURNING ends_at", [c.sub]);
  await q("UPDATE users SET boost_until=$2 WHERE id=$1", [c.sub, b[0].ends_at]);
  return json({ boost_until: b[0].ends_at }, 201);
});
