import { handle, json, requirePermission, body, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";

/**
 * Fixed, policy-reviewed AdMob inventory. The Owner can disable or reduce delivery,
 * but cannot raise frequency beyond these hard-coded safety limits.
 */
const SAFETY_LIMITS: Record<string, { maxPerSession: number; minGapSec: number }> = {
  home_feed: { maxPerSession: 4, minGapSec: 120 },
  tab_transition: { maxPerSession: 3, minGapSec: 180 },
  rewarded_cosmetic: { maxPerSession: 5, minGapSec: 0 },
};

/** Owner-controlled AdMob placements. No chat/auth/safety placement is permitted. */
export const GET = handle(async (r) => {
  await requirePermission(r, "ads.config");
  const rows = await q("SELECT placement,format,enabled,min_gap_sec,max_per_session FROM ad_config ORDER BY placement");
  return json({
    placements: rows.map((row: any) => {
      const limit = SAFETY_LIMITS[row.placement];
      return limit ? {
        ...row,
        max_per_session: Math.min(Number(row.max_per_session), limit.maxPerSession),
        min_gap_sec: Math.max(Number(row.min_gap_sec), limit.minGapSec),
        safety_max_per_session: limit.maxPerSession,
        safety_min_gap_sec: limit.minGapSec,
      } : { ...row, enabled: false, max_per_session: 0 };
    }),
  });
});

export const PUT = handle(async (r) => {
  const c = await requirePermission(r, "ads.config");
  const b = await body(r, x => {
    if (typeof x.placement !== "string") throw new Error("invalid_placement");
    if (x.enabled !== undefined && typeof x.enabled !== "boolean") throw new Error("invalid_enabled");
    if (x.min_gap_sec !== undefined && (!Number.isInteger(x.min_gap_sec) || x.min_gap_sec < 0 || x.min_gap_sec > 3600)) throw new Error("invalid_min_gap_sec");
    if (x.max_per_session !== undefined && (!Number.isInteger(x.max_per_session) || x.max_per_session < 0 || x.max_per_session > 20)) throw new Error("invalid_max_per_session");
    return x as { placement: string; enabled?: boolean; min_gap_sec?: number; max_per_session?: number };
  });
  const limit = SAFETY_LIMITS[b.placement];
  if (!limit) throw new HttpError(403, "placement_not_allowed");
  const minGap = Math.max(b.min_gap_sec ?? limit.minGapSec, limit.minGapSec);
  const maxPerSession = Math.min(b.max_per_session ?? limit.maxPerSession, limit.maxPerSession);
  const u = await q(
    "UPDATE ad_config SET enabled=COALESCE($2,enabled),min_gap_sec=$3,max_per_session=$4 WHERE placement=$1 RETURNING placement",
    [b.placement, b.enabled ?? null, minGap, maxPerSession],
  );
  if (!u.length) throw new HttpError(404, "unknown_placement");
  await audit(c, "ads.update", { type: "ad_placement", id: b.placement }, {
    enabled: b.enabled, min_gap_sec: minGap, max_per_session: maxPerSession,
  }, clientIp(r));
  return json({ ok: true, min_gap_sec: minGap, max_per_session: maxPerSession });
});
