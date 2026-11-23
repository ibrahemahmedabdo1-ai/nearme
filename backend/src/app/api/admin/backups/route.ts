import { handle, json, requirePermission, body, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
/** Owner-only. This records the request and the audit trail; the actual dump is produced by scripts/backup.sh (run by the Owner or CI), never by a web request. */
export const GET = handle(async (r) => { await requirePermission(r, "backup.run"); return json({ backups: await q("SELECT id,scope,status,storage_key,checksum,created_at,restored_at FROM backups ORDER BY created_at DESC LIMIT 100") }); });
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "backup.run");
  const b = await body(r, x => { if (!["database", "files", "settings", "full"].includes(x.scope)) throw new Error("invalid_scope"); return { scope: x.scope as string }; });
  const row = (await q<{ id: string }>("INSERT INTO backups(scope,status,requested_by) VALUES ($1,'requested',$2) RETURNING id", [b.scope, c.sub]))[0];
  await audit(c, "backup.request", { type: "backup", id: row.id }, { scope: b.scope }, clientIp(r));
  return json({ id: row.id, next: "Run scripts/backup.sh with DATABASE_URL to produce the file, then record it with PATCH." }, 201);
});
