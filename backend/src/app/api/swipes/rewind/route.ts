import { handle, json, auth, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
/** Rewind (free): undo my most recent swipe if it happened in the last 5 minutes and did not create a match. */
export const POST = handle(async (r) => {
  const c = await auth(r);
  const last = (await q<any>("SELECT to_user,kind FROM swipes WHERE from_user=$1 AND kind IN ('like','super_like','pass') ORDER BY created_at DESC LIMIT 1", [c.sub]))[0];
  if (!last) throw new HttpError(404, "nothing_to_rewind");
  const [lo, hi] = c.sub < last.to_user ? [c.sub, last.to_user] : [last.to_user, c.sub];
  if ((await q("SELECT 1 FROM matches WHERE user_a=$1 AND user_b=$2", [lo, hi])).length) throw new HttpError(409, "already_matched");
  const del = await q("DELETE FROM swipes WHERE from_user=$1 AND to_user=$2 AND kind=$3 AND created_at>now()-interval '5 minutes' RETURNING to_user", [c.sub, last.to_user, last.kind]);
  if (!del.length) throw new HttpError(409, "rewind_window_closed");
  return json({ restored_user: last.to_user });
});
