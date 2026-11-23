import { createHmac, randomBytes } from "node:crypto";
const A = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
export const newTotpSecret = () => { const b = randomBytes(20); let bits = "", out = ""; for (const x of b) bits += x.toString(2).padStart(8, "0"); for (let i = 0; i < bits.length; i += 5) out += A[parseInt(bits.slice(i, i + 5), 2)]; return out; };
const dec = (s: string) => { let bits = ""; for (const c of s) bits += A.indexOf(c).toString(2).padStart(5, "0"); const o: number[] = []; for (let i = 0; i + 8 <= bits.length; i += 8) o.push(parseInt(bits.slice(i, i + 8), 2)); return Buffer.from(o); };
export function totp(secret: string, t = Date.now(), step = 30, digits = 6): string {
  const c = Buffer.alloc(8); c.writeBigUInt64BE(BigInt(Math.floor(t / 1000 / step)));
  const h = createHmac("sha1", dec(secret)).update(c).digest(); const o = h[19] & 15;
  return String(((h.readUInt32BE(o) & 0x7fffffff) % 10 ** digits)).padStart(digits, "0");
}
export const verifyTotp = (secret: string, code: string, now = Date.now()) => [-1, 0, 1].some(w => totp(secret, now + w * 30000) === code);
