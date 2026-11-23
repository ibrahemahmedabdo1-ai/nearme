import { handle, json, auth, body, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
import { RADIUS_OPTIONS } from "@/domain/matching";
export const GET = handle(async (r) => { const c = await auth(r); return json({ preferences: (await q("SELECT * FROM preferences WHERE user_id=$1", [c.sub]))[0] }); });
export const PUT = handle(async (r) => {
  const c = await auth(r);
  const allowedPin = ((await q<{ value: number[] }>("SELECT value FROM app_config WHERE key='pin.allowed_timeouts_sec'"))[0]?.value ?? [0, 60, 300, 900]);
  const b = await body(r, x => {
    const bool = (v: unknown, n: string) => { if (v !== undefined && typeof v !== "boolean") throw new Error("invalid_" + n); return v as boolean | undefined; };
    if (x.radius_km !== undefined && x.radius_km !== null && !(RADIUS_OPTIONS as readonly number[]).includes(x.radius_km)) throw new Error("invalid_radius");
    if (x.min_age !== undefined && (!Number.isInteger(x.min_age) || x.min_age < 18 || x.min_age > 99)) throw new Error("invalid_min_age");
    if (x.max_age !== undefined && (!Number.isInteger(x.max_age) || x.max_age < 18 || x.max_age > 99)) throw new Error("invalid_max_age");
    if (x.temp_messages !== undefined && !["off", "24h", "7d", "30d"].includes(x.temp_messages)) throw new Error("invalid_temp_messages");
    if (x.language !== undefined && !["ar", "en"].includes(x.language)) throw new Error("invalid_language");
    if (x.theme_mode !== undefined && !["system", "light", "dark"].includes(x.theme_mode)) throw new Error("invalid_theme_mode");
    if (x.genders !== undefined && (!Array.isArray(x.genders) || x.genders.length > 6 || x.genders.some((g: unknown) => typeof g !== "string" || g.length > 20))) throw new Error("invalid_genders");
    if (x.pin_timeout_sec !== undefined && x.pin_timeout_sec !== null && !allowedPin.includes(x.pin_timeout_sec)) throw new Error("pin_timeout_not_allowed");   // Owner defines allowed options
    return { x, radius: x.radius_km, hasRadius: "radius_km" in x, flags: ["verified_only", "show_last_seen", "read_receipts", "show_online", "push_enabled", "occasion_push_enabled"].map(k => [k, bool(x[k], k)] as const) };
  });
  const cur = (await q<any>("SELECT * FROM preferences WHERE user_id=$1", [c.sub]))[0];
  const v = { ...cur, ...Object.fromEntries(b.flags.filter(([, val]) => val !== undefined)), ...Object.fromEntries(["min_age", "max_age", "temp_messages", "language", "theme_mode", "genders", "pin_timeout_sec"].filter(k => k in b.x).map(k => [k, b.x[k]])) };
  if (b.hasRadius) v.radius_km = b.radius;
  if (v.max_age < v.min_age) throw new HttpError(422, "invalid_age_range");
  await q(`UPDATE preferences SET radius_km=$2,min_age=$3,max_age=$4,genders=$5,verified_only=$6,show_last_seen=$7,read_receipts=$8,show_online=$9,temp_messages=$10,pin_timeout_sec=$11,language=$12,theme_mode=$13,push_enabled=$14,occasion_push_enabled=$15 WHERE user_id=$1`,
    [c.sub, v.radius_km, v.min_age, v.max_age, v.genders, v.verified_only, v.show_last_seen, v.read_receipts, v.show_online, v.temp_messages, v.pin_timeout_sec, v.language, v.theme_mode, v.push_enabled, v.occasion_push_enabled]);
  return json({ ok: true });
});
