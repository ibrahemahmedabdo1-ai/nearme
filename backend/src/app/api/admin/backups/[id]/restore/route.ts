import { handle, json, requirePermission, body, str, HttpError, audit, clientIp, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
import { verifyTotp } from "@/lib/totp";
import { decrypt } from "@/lib/crypto";
import { env } from "@/lib/env";
/** Restore authorization: Owner + typed confirmation "RESTORE <backup id>" + fresh TOTP. It only AUTHORIZES; scripts/restore.sh performs the restore. */
export const POST = handle(async (r, { params }) => {
  const c = await requirePermission(r, "backup.run"); rateLimit(r, "restore", 5, 600_000, c.sub); const { id } = await params;
  const b = await body(r, x => ({ confirm: str(x.confirm, "confirm", 1, 100), totp: str(x.totp, "totp", 6, 6) }));
  if (b.confirm !== `RESTORE ${id}`) throw new HttpError(422, "confirmation_mismatch");
  const u = (await q<{ totp_secret_enc: string }>("SELECT totp_secret_enc FROM users WHERE id=$1", [c.sub]))[0];
  if (!verifyTotp(decrypt(u.totp_secret_enc, env("DATA_ENCRYPTION_KEY")), b.totp)) throw new HttpError(401, "2fa_required");
  const k = await q("UPDATE backups SET status='restore_authorized' WHERE id=$1 RETURNING id", [id]); if (!k.length) throw new HttpError(404, "not_found");
  await audit(c, "backup.restore_authorize", { type: "backup", id }, {}, clientIp(r));
  return json({ authorized: true, next: "Run scripts/restore.sh <file> against the target database." });
});
