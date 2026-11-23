import { handle, json, body, str, rateLimit, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
import { hashToken } from "@/lib/emailTokens";
import { hashPassword, validatePasswordStrength } from "@/domain/password";
export const POST = handle(async (r) => {
  rateLimit(r, "reset", 20, 3_600_000);
  const b = await body(r, x => ({ token: str(x.token, "token", 20, 200), password: str(x.password, "password", 10, 128) }));
  const weak = validatePasswordStrength(b.password); if (weak) throw new HttpError(422, weak);
  // Atomic single-use: UPDATE ... RETURNING guarantees only one request can consume the token.
  const t = (await q<{ user_id: string }>("UPDATE email_tokens SET used_at=now() WHERE token_hash=$1 AND purpose='reset_password' AND used_at IS NULL AND expires_at>now() RETURNING user_id", [hashToken(b.token)]))[0];
  if (!t) throw new HttpError(400, "invalid_or_expired_token");
  await q("UPDATE users SET password_hash=$2 WHERE id=$1", [t.user_id, await hashPassword(b.password)]);
  await q("UPDATE sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL", [t.user_id]);   // log out everywhere
  await audit(null, "auth.password_reset", { type: "user", id: t.user_id }, {}, clientIp(r));
  return json({ ok: true });
});
