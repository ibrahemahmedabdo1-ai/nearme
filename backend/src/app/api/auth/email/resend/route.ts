import { handle, json, auth, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
import { sendEmailToken } from "@/lib/emailTokens";
export const POST = handle(async (r) => {
  const c = await auth(r); rateLimit(r, "resend", 3, 3_600_000, c.sub);
  const u = (await q<{ email: string; v: boolean }>("SELECT email, email_verified_at IS NOT NULL AS v FROM users WHERE id=$1", [c.sub]))[0];
  if (u?.email && !u.v) await sendEmailToken(c.sub, u.email, "verify_email");
  return json({ ok: true }, 202);
});
