import { handle, json, requirePermission, body, str, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => { await requirePermission(r, "release.manage"); return json({ releases: await q("SELECT * FROM app_releases ORDER BY version_code DESC LIMIT 50") }); });
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "release.manage");   // owner only
  const b = await body(r, x => ({ name: str(x.version_name, "version_name", 1, 30), code: Number.isInteger(x.version_code) && x.version_code > 0 ? (x.version_code as number) : (() => { throw new Error("invalid_version_code"); })(), min: x.min_required === true, forced: x.forced_security === true, pct: Number.isInteger(x.rollout_percent) ? Math.min(100, Math.max(0, x.rollout_percent)) : 0, notes: x.notes ? str(x.notes, "notes", 1, 2000) : null }));
  const row = (await q<{ id: number }>("INSERT INTO app_releases(version_name,version_code,min_required,forced_security,rollout_percent,notes,created_by) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id", [b.name, b.code, b.min, b.forced, b.pct, b.notes, c.sub]))[0];
  await audit(c, "release.create", { type: "release", id: String(row.id) }, { code: b.code, min: b.min, forced: b.forced }, clientIp(r));
  return json({ id: row.id }, 201);
});
