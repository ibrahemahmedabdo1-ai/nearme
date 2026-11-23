import { handle, json, requirePermission, body, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
/** Owner-controlled AdMob placements. Only the fixed placements exist; none can be created for chat/auth/safety screens. */
export const GET = handle(async (r) => { await requirePermission(r, "ads.config"); return json({ placements: await q("SELECT placement,format,enabled,min_gap_sec,max_per_session FROM ad_config ORDER BY placement") }); });
export const PUT = handle(async (r) => {
  const c = await requirePermission(r, "ads.config");
  const b = await body(r, x => {
    if (typeof x.placement !== "string") throw new Error("invalid_placement");
    if (x.enabled !== undefined && typeof x.enabled !== "boolean") throw new Error("invalid_enabled");
    if (x.min_gap_sec !== undefined && (!Number.isInteger(x.min_gap_sec) || x.min_gap_sec < 30 || x.min_gap_sec > 3600)) throw new Error("invalid_min_gap_sec");
    if (x.max_per_session !== undefined && (!Number.isInteger(x.max_per_session) || x.max_per_session < 0 || x.max_per_session > 20)) throw new Error("invalid_max_per_session");
    return x as { placement: string; enabled?: boolean; min_gap_sec?: number; max_per_session?: number };
  });
  const u = await q("UPDATE ad_config SET enabled=COALESCE($2,enabled),min_gap_sec=COALESCE($3,min_gap_sec),max_per_session=COALESCE($4,max_per_session) WHERE placement=$1 RETURNING placement", [b.placement, b.enabled ?? null, b.min_gap_sec ?? null, b.max_per_session ?? null]);
  if (!u.length) throw new HttpError(404, "unknown_placement");
  await audit(c, "ads.update", { type: "ad_placement", id: b.placement }, { enabled: b.enabled }, clientIp(r)); return json({ ok: true });
});
