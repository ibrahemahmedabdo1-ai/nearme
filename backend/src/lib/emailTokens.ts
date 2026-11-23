import { createHash, randomBytes } from "node:crypto";
import { q } from "./db";
import { getProviders } from "@/providers";
export const hashToken = (t: string) => createHash("sha256").update(t).digest("hex");
/** Creates a single-use token (stored hashed) and emails the link. Returns false if the provider is not configured. */
export async function sendEmailToken(userId: string, to: string, purpose: "verify_email" | "reset_password"): Promise<boolean> {
  const raw = randomBytes(32).toString("base64url");
  await q("INSERT INTO email_tokens(user_id,purpose,token_hash,expires_at) VALUES ($1,$2,$3, now() + ($4 || ' minutes')::interval)", [userId, purpose, hashToken(raw), purpose === "reset_password" ? "60" : "1440"]);
  const base = process.env.APP_PUBLIC_URL ?? "";
  const subject = purpose === "reset_password" ? "Reset your NEAR ME password" : "Verify your NEAR ME email";
  const html = `<p>${subject}</p><p><a href="${base}/${purpose === "reset_password" ? "reset" : "verify"}?token=${raw}">Open link</a></p><p>Token: ${raw}</p><p>If you did not request this, ignore this email.</p>`;
  const r = await getProviders().email.send(to, subject, html);
  return r.ok;
}
