import { handle, json, requirePermission, body, str, HttpError, audit, clientIp, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
import { verifyPassword } from "@/domain/password";
import { newTotpSecret, verifyTotp } from "@/lib/totp";
import { encrypt, decrypt } from "@/lib/crypto";
import { env } from "@/lib/env";
import { createHash, randomBytes } from "node:crypto";
/** Owner rotates their 2FA secret and receives 10 one-time recovery codes (shown once). Requires current password AND current TOTP. */
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "owner.credentials"); rateLimit(r, "owner-cred", 5, 600_000, c.sub);
  const b = await body(r, x => ({ password: str(x.password, "password", 1, 200), totp: str(x.totp, "totp", 6, 6) }));
  const u = (await q<any>("SELECT password_hash,totp_secret_enc FROM users WHERE id=$1", [c.sub]))[0];
  if (!(await verifyPassword(b.password, u.password_hash)) || !verifyTotp(decrypt(u.totp_secret_enc, env("DATA_ENCRYPTION_KEY")), b.totp)) throw new HttpError(401, "invalid_credentials");
  const secret = newTotpSecret(); const codes = Array.from({ length: 10 }, () => randomBytes(6).toString("hex"));
  await q("UPDATE users SET totp_secret_enc=$2 WHERE id=$1", [c.sub, encrypt(secret, env("DATA_ENCRYPTION_KEY"))]);
  await q("DELETE FROM owner_recovery_codes WHERE user_id=$1", [c.sub]);
  for (const k of codes) await q("INSERT INTO owner_recovery_codes(user_id,code_hash) VALUES ($1,$2)", [c.sub, createHash("sha256").update(k).digest("hex")]);
  await audit(c, "owner.2fa_rotate", { type: "user", id: c.sub }, {}, clientIp(r));
  return json({ totp_secret: secret, recovery_codes: codes });
});
