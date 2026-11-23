import { handle, json, getEmergencyMode } from "@/lib/http";
import { q } from "@/lib/db";
export const dynamic = "force-dynamic";
// Public bootstrap config: emergency mode, minimum app version, remotely-configurable (data-only) settings.
export const GET = handle(async () => {
  const [mode, rel, ads, cfg] = await Promise.all([getEmergencyMode(), q("SELECT version_code,forced_security FROM app_releases WHERE min_required ORDER BY version_code DESC LIMIT 1"), q("SELECT placement,format,enabled,min_gap_sec,max_per_session FROM ad_config"), q("SELECT key,value FROM app_config WHERE key LIKE 'builder.%' OR key IN ('intro.rule','messages.delete_for_both_minutes','messages.max_file_mb','pin.allowed_timeouts_sec','support.allow_anonymous_identity')")]);   // public whitelist: matching weights etc. stay private
  return json({ emergency_mode: mode, min_version_code: rel[0]?.version_code ?? 0, forced_update: rel[0]?.forced_security ?? false, ads, config: Object.fromEntries(cfg.map((c: any) => [c.key, c.value])) });
});
