import { handle, json, auth, body, HttpError, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
import { getProviders } from "@/providers";
import { randomUUID } from "node:crypto";
const METHODS = ["profile_image", "live_selfie", "id_document"];
/** Submits a verification request. Evidence goes to private object storage (never Postgres). AI only scores; humans decide. */
export const POST = handle(async (r) => {
  const c = await auth(r); rateLimit(r, "verify-submit", 5, 86_400_000, c.sub);
  const { method } = await body(r, x => { if (!METHODS.includes(x.method)) throw new Error("invalid_method"); return { method: x.method as string }; });
  const key = `evidence/${c.sub}/${randomUUID()}`;
  const up = await getProviders().storage.presignUpload(key, "image/jpeg", 8 * 1024 * 1024);
  if (!up.ok) throw new HttpError(501, "storage_not_configured");
  const row = (await q<{ id: string }>("INSERT INTO verifications(user_id,method,evidence_storage_key,evidence_delete_after) VALUES ($1,$2,$3, now() + interval '30 days') RETURNING id", [c.sub, method, key]))[0];
  return json({ verification_id: row.id, upload_url: up.data.url }, 201);   // AI analysis (provider adapter) runs after upload; result is advisory
});
