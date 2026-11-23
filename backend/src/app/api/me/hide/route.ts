import { handle, json, auth, body } from "@/lib/http";
import { q } from "@/lib/db";
/** Temporarily hide the profile from discovery: {hours: 1..720} or {hours: null} to show again. */
export const POST = handle(async (r) => {
  const c = await auth(r);
  const { hours } = await body(r, x => { if (x.hours !== null && (!Number.isInteger(x.hours) || x.hours < 1 || x.hours > 720)) throw new Error("invalid_hours"); return { hours: x.hours as number | null }; });
  await q("UPDATE users SET hidden_until = CASE WHEN $2::int IS NULL THEN NULL ELSE now() + ($2::int || ' hours')::interval END WHERE id=$1", [c.sub, hours]);
  return json({ ok: true });
});
