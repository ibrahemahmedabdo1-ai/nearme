import { handle, json, requirePermission, body, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
import { PERMISSIONS, OWNER_ONLY } from "@/domain/permissions";
/** Owner-only: enable/disable, grant/revoke extra permissions (never owner-only ones), revoke sessions. */
export const PATCH = handle(async (r, { params }) => {
  const c = await requirePermission(r, "accounts.manage_staff"); const { id } = await params;
  const b = await body(r, x => {
    if (x.disabled !== undefined && typeof x.disabled !== "boolean") throw new Error("invalid_disabled");
    if (x.permissions !== undefined && (!Array.isArray(x.permissions) || x.permissions.some((p: unknown) => !(PERMISSIONS as readonly string[]).includes(p as string)))) throw new Error("invalid_permissions");
    return { disabled: x.disabled as boolean | undefined, permissions: x.permissions as string[] | undefined };
  });
  const t = (await q<{ role: string }>("SELECT role FROM users WHERE id=$1", [id]))[0];
  if (!t || !["admin", "support"].includes(t.role)) throw new HttpError(404, "not_found");   // the Owner account is never editable here
  if (b.permissions?.some(p => (OWNER_ONLY as ReadonlySet<string>).has(p))) throw new HttpError(403, "owner_only_permission");
  if (b.permissions) {
    await q("DELETE FROM staff_permissions WHERE user_id=$1", [id]);
    for (const p of new Set(b.permissions)) await q("INSERT INTO staff_permissions(user_id,permission,granted_by) VALUES ($1,$2,$3)", [id, p, c.sub]);
  }
  if (b.disabled !== undefined) {
    await q("UPDATE users SET disabled_by_owner=$2 WHERE id=$1", [id, b.disabled]);
    if (b.disabled) await q("UPDATE sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL", [id]);
  }
  await audit(c, "staff.update", { type: "user", id }, { disabled: b.disabled, permissions: b.permissions }, clientIp(r));
  return json({ ok: true });
});
export const DELETE = handle(async (r, { params }) => {   // revoke all sessions of a staff member
  const c = await requirePermission(r, "accounts.manage_staff"); const { id } = await params;
  const n = await q("UPDATE sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL RETURNING id", [id]);
  await audit(c, "staff.revoke_sessions", { type: "user", id }, { count: n.length }, clientIp(r)); return json({ revoked: n.length });
});
