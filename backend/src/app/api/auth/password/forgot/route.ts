import { handle, json, body, email, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
import { sendEmailToken } from "@/lib/emailTokens";
export const POST = handle(async (r) => {
  const b = await body(r, x => ({ email: email(x.email) }));
  rateLimit(r, "forgot-ip", 10, 3_600_000); rateLimit(r, "forgot-acct", 3, 3_600_000, b.email);
  const u = (await q<{ id: string }>("SELECT id FROM users WHERE email=$1 AND status NOT IN ('deleted','banned')", [b.email]))[0];
  if (u) await sendEmailToken(u.id, b.email, "reset_password");
  return json({ ok: true }, 202);   // identical response whether or not the account exists (no enumeration)
});
