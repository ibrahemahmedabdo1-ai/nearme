import { handle, json, body, str, rateLimit, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
import { hashToken } from "@/lib/emailTokens";
export const POST = handle(async (r) => {
  rateLimit(r, "verify", 30, 3_600_000);
  const { token } = await body(r, x => ({ token: str(x.token, "token", 20, 200) }));
  const t = (await q<{ user_id: string }>("UPDATE email_tokens SET used_at=now() WHERE token_hash=$1 AND purpose='verify_email' AND used_at IS NULL AND expires_at>now() RETURNING user_id", [hashToken(token)]))[0];
  if (!t) throw new HttpError(400, "invalid_or_expired_token");
  await q("UPDATE users SET email_verified_at=now() WHERE id=$1", [t.user_id]);
  return json({ ok: true });
});
