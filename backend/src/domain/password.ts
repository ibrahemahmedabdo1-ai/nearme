import { randomBytes, scrypt as _scrypt, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";
const scrypt = promisify(_scrypt) as (p: string, s: Buffer, n: number, o: object) => Promise<Buffer>;
const P = { N: 2 ** 15, r: 8, p: 1, maxmem: 128 * 1024 * 1024 };

export function validatePasswordStrength(pw: string): string | null {
  if (pw.length < 10) return "password_too_short";
  if (pw.length > 128) return "password_too_long";
  if (!/[a-z]/.test(pw) || !/[A-Z]/.test(pw) || !/[0-9]/.test(pw)) return "password_too_weak";
  return null;
}
export async function hashPassword(pw: string): Promise<string> {
  const salt = randomBytes(16);
  const key = await scrypt(pw.normalize("NFKC"), salt, 64, P);
  return `scrypt$${P.N}$${P.r}$${P.p}$${salt.toString("base64")}$${key.toString("base64")}`;
}
export async function verifyPassword(pw: string, stored: string): Promise<boolean> {
  const [alg, N, r, p, saltB64, keyB64] = stored.split("$");
  if (alg !== "scrypt") return false;
  const expected = Buffer.from(keyB64, "base64");
  const key = await scrypt(pw.normalize("NFKC"), Buffer.from(saltB64, "base64"), expected.length,
    { N: +N, r: +r, p: +p, maxmem: P.maxmem });
  return key.length === expected.length && timingSafeEqual(key, expected);
}
