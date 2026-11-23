import { handle, json, auth, body, str, HttpError, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
import { checkUpload } from "@/domain/messaging";
import { getProviders } from "@/providers";
import { randomUUID } from "node:crypto";
/** Step 1: client announces file metadata + first bytes (base64, <=32 bytes) -> server validates and returns a presigned upload URL.
 *  Step 2: client PUTs to object storage. Step 3: POST /api/uploads/complete triggers the malware scan; messages can only reference scan_status='clean'. */
export const POST = handle(async (r) => {
  const c = await auth(r); rateLimit(r, "upload", 60, 3_600_000, c.sub);
  const b = await body(r, x => ({ name: str(x.name, "name", 1, 120), mime: str(x.mime, "mime", 3, 100), size: Number.isInteger(x.size) ? (x.size as number) : (() => { throw new Error("invalid_size"); })(), head: Buffer.from(str(x.head_b64, "head_b64", 4, 64), "base64"), sha256: str(x.sha256, "sha256", 64, 64) }));
  const maxMb = Number((await q<{ value: unknown }>("SELECT value FROM app_config WHERE key='messages.max_file_mb'"))[0]?.value ?? 10);
  const v = checkUpload(b.name, b.mime, b.size, maxMb * 1024 * 1024, b.head);
  if (!v.ok) throw new HttpError(422, v.reason);
  const key = `u/${c.sub}/${randomUUID()}.${v.ext}`;
  const url = await getProviders().storage.presignUpload(key, b.mime, maxMb * 1024 * 1024);
  if (!url.ok) throw new HttpError(501, "storage_not_configured");
  const row = (await q<{ id: string }>("INSERT INTO attachments(owner_id,storage_key,mime,size_bytes,sha256) VALUES ($1,$2,$3,$4,$5) RETURNING id", [c.sub, key, b.mime, b.size, b.sha256]))[0];
  return json({ attachment_id: row.id, upload_url: url.data.url }, 201);
});
