import { handle, json, body, str, email, rateLimit, guardMode, HttpError, clientIp, audit } from "@/lib/http";
import { q } from "@/lib/db";
import { verifyPassword, hashPassword } from "@/domain/password";
import { issueSession } from "@/lib/session";
import { verifyTotp } from "@/lib/totp";
import { decrypt } from "@/lib/crypto";
import { env } from "@/lib/env";
import { createHash } from "node:crypto";
type U = { disabled_by_owner: boolean; id: string; password_hash: string | null; role: "customer" | "support" | "admin" | "owner"; status: string; totp_secret_enc: string | null };
let DUMMY: string | null = null;
export const POST = handle(async (r) => {
  const b = await body(r, x => ({ email: email(x.email), password: str(x.password, "password", 1, 128), totp: x.totp === undefined ? undefined : str(x.totp, "totp", 6, 6), recovery_code: x.recovery_code === undefined ? undefined : str(x.recovery_code, "recovery_code", 8, 40), install_id: x.install_id === undefined ? undefined : str(x.install_id, "install_id", 16, 128) }));
  rateLimit(r, "login-ip", 30, 900_000); rateLimit(r, "login-acct", 8, 900_000, b.email);
  const u = (await q<U>("SELECT id,password_hash,role,status,totp_secret_enc,disabled_by_owner FROM users WHERE email=$1", [b.email]))[0];
  DUMMY ??= await hashPassword("dummy-password-for-timing");
  const okPw = await verifyPassword(b.password, u?.password_hash ?? DUMMY); // constant-ish time even for unknown accounts
  if (!u || !okPw) { await audit(null, "auth.login_failed", undefined, { email_hash: b.email.length }, clientIp(r)); throw new HttpError(401, "invalid_credentials"); }
  if (u.status === "banned" || u.status === "deleted") throw new HttpError(403, "account_unavailable");
  let deviceId: string | null = null;
  if (u.role !== "customer") {   // staff and owner: mandatory 2FA (Owner may use a one-time recovery code instead)
    if (!u.totp_secret_enc) throw new HttpError(403, "2fa_enrollment_required");
    const totpOk = !!b.totp && verifyTotp(decrypt(u.totp_secret_enc, env("DATA_ENCRYPTION_KEY")), b.totp);
    let recOk = false;
    if (!totpOk && b.recovery_code && u.role === "owner") {
      recOk = (await q("UPDATE owner_recovery_codes SET used_at=now() WHERE user_id=$1 AND code_hash=$2 AND used_at IS NULL RETURNING 1", [u.id, createHash("sha256").update(b.recovery_code).digest("hex")])).length > 0;
      if (recOk) await q("INSERT INTO security_events(user_id,kind) VALUES ($1,'owner_recovery_code_used')", [u.id]);
    }
    if (!totpOk && !recOk) throw new HttpError(401, "2fa_required");
  } else {   // customers: one account per device -- the account may only sign in from its registered (non-revoked) device
    if (!b.install_id) throw new HttpError(422, "install_id_required");
    const d = (await q<{ id: string }>("SELECT id FROM devices WHERE user_id=$1 AND install_id_hash=$2 AND revoked_at IS NULL", [u.id, createHash("sha256").update(b.install_id).digest("hex")]))[0];
    if (!d) { await q("INSERT INTO security_events(user_id,kind) VALUES ($1,'login_unregistered_device')", [u.id]); throw new HttpError(403, "device_not_registered"); }
    deviceId = d.id; await q("UPDATE devices SET last_seen_at=now() WHERE id=$1", [d.id]);
  }
  if (u.disabled_by_owner) throw new HttpError(403, "account_unavailable");
  await guardMode("read", { sub: u.id, role: u.role, sid: "", exp: 0, iat: 0 });
  await q("UPDATE users SET last_seen_at=now() WHERE id=$1", [u.id]);
  await audit(null, "auth.login", { type: "user", id: u.id }, {}, clientIp(r));
  return json(await issueSession(u.id, u.role, deviceId, clientIp(r)));
});
