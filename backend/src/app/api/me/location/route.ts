import { handle, json, auth, body, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
// Stores only a coarse cell (~1 km grid), never exact coordinates, never history.
export const POST = handle(async (r) => {
  const c = await auth(r);
  const b = await body(r, x => { if (typeof x.lat !== "number" || typeof x.lon !== "number" || Math.abs(x.lat) > 90 || Math.abs(x.lon) > 180) throw new Error("invalid_coordinates"); return x as { lat: number; lon: number }; });
  const snap = (v: number) => Math.round(v * 100) / 100;
  await q("UPDATE users SET lat_cell=$2,lon_cell=$3,last_seen_at=now() WHERE id=$1", [c.sub, snap(b.lat), snap(b.lon)]);
  return json({ ok: true });
});
