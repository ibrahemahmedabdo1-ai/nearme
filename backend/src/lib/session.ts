import { q } from "./db";
import { env } from "./env";
import { signAccessToken, newRefreshToken } from "@/domain/tokens";
import type { Role } from "@/domain/permissions";
const REFRESH_DAYS = 30;
export async function issueSession(userId: string, role: Role, deviceId: string | null, ip: string, familyId?: string) {
  const rt = newRefreshToken();
  const rows = await q<{ id: string }>(
    `INSERT INTO sessions(user_id,device_id,family_id,refresh_hash,expires_at,ip) VALUES ($1,$2,COALESCE($3::uuid,gen_random_uuid()),$4, now() + ($5 || ' days')::interval,$6) RETURNING id`,
    [userId, deviceId, familyId ?? null, rt.hash, String(REFRESH_DAYS), ip === "unknown" ? null : ip]);
  const access = signAccessToken({ sub: userId, role, sid: rows[0].id }, env("JWT_SECRET"));
  return { access_token: access, refresh_token: rt.raw, expires_in: 900 };
}
