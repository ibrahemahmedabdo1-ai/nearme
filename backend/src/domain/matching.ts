export type Weights = { interests: number; distance: number; age: number; activity: number; verified: number };
export const DEFAULT_WEIGHTS: Weights = { interests: 40, distance: 25, age: 15, activity: 10, verified: 10 };
export type Cand = { interests: string[]; distanceKm: number | null; age: number; lastActiveMs: number; verified: boolean };
export type Seeker = { interests: string[]; radiusKm: number | null; minAge: number; maxAge: number };
export const RADIUS_OPTIONS = [1, 5, 10, 25, 50, 100] as const;
export const DEFAULT_RADIUS_KM = 25;

export function haversineKm(a: [number, number], b: [number, number]): number {
  const R = 6371, rad = (d: number) => d * Math.PI / 180;
  const dLat = rad(b[0] - a[0]), dLon = rad(b[1] - a[1]);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a[0])) * Math.cos(rad(b[0])) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}
/** Privacy: only an approximate distance is ever exposed (rounded up to 0.5 km below 10 km, 1 km otherwise, min 0.5). */
export function approxDistance(km: number): number {
  const step = km < 10 ? 0.5 : 1;
  return Math.max(0.5, Math.ceil(km / step) * step);
}
export function withinRadius(km: number | null, radiusKm: number | null): boolean {
  return radiusKm === null || (km !== null && km <= radiusKm);
}
export function compatibility(s: Seeker, c: Cand, w: Weights = DEFAULT_WEIGHTS, now = Date.now()) {
  const total = w.interests + w.distance + w.age + w.activity + w.verified;
  if (total <= 0) throw new Error("weights must sum > 0");
  const shared = c.interests.filter(i => s.interests.includes(i));
  const union = new Set([...s.interests, ...c.interests]).size;
  const fInterests = union ? shared.length / union : 0;
  const fDistance = c.distanceKm === null ? 0.5 : s.radiusKm ? Math.max(0, 1 - c.distanceKm / s.radiusKm) : Math.max(0, 1 - c.distanceKm / 200);
  const fAge = c.age >= s.minAge && c.age <= s.maxAge ? 1 : 0;
  const hours = (now - c.lastActiveMs) / 3.6e6;
  const fActivity = hours <= 1 ? 1 : hours >= 168 ? 0 : 1 - (hours - 1) / 167;
  const fVerified = c.verified ? 1 : 0;
  const parts = { interests: fInterests, distance: fDistance, age: fAge, activity: fActivity, verified: fVerified };
  const score = Math.round(100 * (w.interests * fInterests + w.distance * fDistance + w.age * fAge + w.activity * fActivity + w.verified * fVerified) / total);
  const reasons: string[] = [];
  if (shared.length) reasons.push(`shared_interests:${shared.slice(0, 3).join(",")}`);
  if (fDistance > 0.7) reasons.push("very_close");
  if (fActivity > 0.8) reasons.push("recently_active");
  if (c.verified) reasons.push("verified_profile");
  return { score, reasons, parts };
}
