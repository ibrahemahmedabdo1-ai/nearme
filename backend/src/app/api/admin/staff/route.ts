import { handle, json, requirePermission, body, str, email, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
import { hashPassword } from "@/domain/password";
import { newTotpSecret } from "@/lib/totp";
import { encrypt } from "@/lib/crypto";
import { env } from "@/lib/env";
import { randomBytes } from "node:crypto";
/** Owner-only staff management. The initial password and TOTP secret are returned ONCE and never stored in clear. */
export const GET = handle(async (r) => {
  await requirePermission(r, "accounts.manage_staff");
  return json({ staff: await q("SELECT u.id,u.email,u.display_name,u.role,u.status,u.disabled_by_owner,u.created_at,coalesce((SELECT array_agg(permission) FROM staff_permissions p WHERE p.user_id=u.id),'{}') AS extra_permissions FROM users u WHERE u.role IN ('admin','support') ORDER BY u.created_at DESC") });
});
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "accounts.manage_staff");
  const b = await body(r, x => { if (!["admin", "support"].includes(x.role)) throw new Error("invalid_role"); return { email: email(x.email), name: str(x.display_name, "display_name", 2, 40), role: x.role as string }; });
  if ((await q("SELECT 1 FROM users WHERE email=$1", [b.email])).length) throw new HttpError(409, "email_taken");
  const password = randomBytes(15).toString("base64url") + "aA1!"; const secret = newTotpSecret();
  const u = (await q<{ id: string }>("INSERT INTO users(email,email_verified_at,password_hash,role,display_name,birthdate,totp_secret_enc) VALUES ($1,now(),$2,$3,$4,'1980-01-01',$5) RETURNING id", [b.email, await hashPassword(password), b.role, b.name, encrypt(secret, env("DATA_ENCRYPTION_KEY"))]))[0];
  await audit(c, "staff.create", { type: "user", id: u.id }, { role: b.role }, clientIp(r));
  return json({ id: u.id, initial_password: password, totp_secret: secret, otpauth_uri: `otpauth://totp/NearMe:${encodeURIComponent(b.email)}?secret=${secret}&issuer=NearMe` }, 201);
});
