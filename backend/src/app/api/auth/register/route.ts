import { handle, json, body, str, email, rateLimit, guardMode, HttpError, clientIp, audit } from "@/lib/http";
import { q } from "@/lib/db";
import { hashPassword, validatePasswordStrength } from "@/domain/password";
import { isAdult } from "@/domain/policy";
import { issueSession } from "@/lib/session";
import { createHash } from "node:crypto";
import { sendEmailToken } from "@/lib/emailTokens";

export const POST = handle(async (r) => {
  rateLimit(r, "register", 10, 3_600_000);
  await guardMode("register");
  const b = await body(r, x => {
    const interests = x.interests === undefined ? [] : x.interests;
    if (!Array.isArray(interests) || interests.length > 10 || interests.some((v: unknown) => typeof v !== "string" || v.length > 40)) throw new Error("invalid_interests");
    const minAge = x.min_age === undefined ? 18 : x.min_age;
    const maxAge = x.max_age === undefined ? 99 : x.max_age;
    const genders = x.genders === undefined ? [] : x.genders;
    if (!Array.isArray(genders) || genders.length > 3 || genders.some((g: unknown) => typeof g !== 'string' || !['male','female','other'].includes(g))) throw new Error('invalid_genders');
    if (!Number.isInteger(minAge) || minAge < 18 || minAge > 99 || !Number.isInteger(maxAge) || maxAge < 18 || maxAge > 99 || maxAge < minAge) throw new Error("invalid_age_range");
    const gender = x.gender === undefined || x.gender === null || x.gender === "" ? null : str(x.gender, "gender", 1, 24);
    if (gender !== null && !["male", "female", "other", "prefer_not_to_say"].includes(gender)) throw new Error("invalid_gender");
    return {
      email: email(x.email), password: str(x.password, "password", 10, 128), display_name: str(x.display_name, "display_name", 2, 40),
      birthdate: str(x.birthdate, "birthdate", 10, 10), install_id: str(x.install_id, "install_id", 16, 128), accept_terms: x.accept_terms === true,
      genders: [...new Set(genders as string[])], gender, bio: x.bio === undefined || x.bio === "" ? null : str(x.bio, "bio", 1, 500),
      interests: [...new Set(interests as string[])], min_age: minAge as number, max_age: maxAge as number,
    };
  });
  if (!b.accept_terms) throw new HttpError(422, "terms_required");
  const bd = new Date(b.birthdate + "T00:00:00Z"); if (isNaN(+bd)) throw new HttpError(422, "invalid_birthdate");
  if (!isAdult(bd)) throw new HttpError(403, "age_restricted");
  const weak = validatePasswordStrength(b.password); if (weak) throw new HttpError(422, weak);
  const idHash = createHash("sha256").update(b.install_id).digest("hex");
  if ((await q("SELECT 1 FROM devices WHERE install_id_hash=$1 AND revoked_at IS NULL", [idHash])).length) throw new HttpError(409, "device_already_registered");
  const found = b.interests.length ? await q<{ id: number; slug: string }>("SELECT id,slug FROM interests WHERE slug = ANY($1::text[])", [b.interests]) : [];
  if (found.length !== b.interests.length) throw new HttpError(422, "unknown_interest");
  const hash = await hashPassword(b.password);
  let uid: string;
  try {
    uid = (await q<{ id: string }>("INSERT INTO users(email,password_hash,display_name,birthdate,gender,bio) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id", [b.email, hash, b.display_name, b.birthdate, b.gender, b.bio]))[0].id;
  } catch (e: any) { if (e?.code === "23505") throw new HttpError(409, "email_taken"); throw e; }
  await q("INSERT INTO preferences(user_id,min_age,max_age,genders) VALUES ($1,$2,$3,$4)", [uid, b.min_age, b.max_age, b.genders]);
  for (const interest of found) await q("INSERT INTO user_interests(user_id,interest_id) VALUES ($1,$2)", [uid, interest.id]);
  const dev = await q<{ id: string }>("INSERT INTO devices(user_id,install_id_hash) VALUES ($1,$2) RETURNING id", [uid, idHash]);
  await audit(null, "user.register", { type: "user", id: uid }, {}, clientIp(r));
  const mailed = await sendEmailToken(uid, b.email, "verify_email");
  return json({ user_id: uid, email_verification: mailed ? "sent" : "pending_provider_not_configured", ...(await issueSession(uid, "customer", dev[0].id, clientIp(r))) }, 201);
});
