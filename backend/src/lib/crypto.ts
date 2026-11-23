import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";
/** AES-256-GCM envelope for sensitive columns (e.g., TOTP secrets, ID-document keys). Output: v1.iv.tag.ct (base64url). */
export function encrypt(plain: string, keyB64: string): string {
  const key = Buffer.from(keyB64, "base64"); if (key.length !== 32) throw new Error("DATA_ENCRYPTION_KEY must be 32 bytes");
  const iv = randomBytes(12), c = createCipheriv("aes-256-gcm", key, iv);
  const ct = Buffer.concat([c.update(plain, "utf8"), c.final()]);
  return ["v1", iv.toString("base64url"), c.getAuthTag().toString("base64url"), ct.toString("base64url")].join(".");
}
export function decrypt(token: string, keyB64: string): string {
  const [v, iv, tag, ct] = token.split("."); if (v !== "v1") throw new Error("bad envelope");
  const d = createDecipheriv("aes-256-gcm", Buffer.from(keyB64, "base64"), Buffer.from(iv, "base64url"));
  d.setAuthTag(Buffer.from(tag, "base64url"));
  return Buffer.concat([d.update(Buffer.from(ct, "base64url")), d.final()]).toString("utf8");
}
