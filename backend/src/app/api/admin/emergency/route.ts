import { handle, json, requirePermission, body, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
import { EMERGENCY_MODES } from "@/domain/policy";
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "emergency.control");   // owner only
  const { mode } = await body(r, x => { if (!EMERGENCY_MODES.includes(x.mode)) throw new Error("invalid_mode"); return { mode: x.mode as string }; });
  await q("UPDATE emergency_state SET mode=$1,changed_by=$2,changed_at=now() WHERE id", [mode, c.sub]);
  if (mode === "security_lockdown" || mode === "full_shutdown") await q("UPDATE sessions SET revoked_at=now() WHERE revoked_at IS NULL AND user_id IN (SELECT id FROM users WHERE role<>'owner')");
  await audit(c, "emergency.set_mode", { type: "system", id: "emergency" }, { mode }, clientIp(r));
  return json({ mode });
});
