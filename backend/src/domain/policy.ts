export function ageFromBirthdate(birth: Date, now = new Date()): number {
  let a = now.getUTCFullYear() - birth.getUTCFullYear();
  const m = now.getUTCMonth() - birth.getUTCMonth();
  if (m < 0 || (m === 0 && now.getUTCDate() < birth.getUTCDate())) a--;
  return a;
}
export const isAdult = (birth: Date, now = new Date()) => ageFromBirthdate(birth, now) >= 18;

export type AdSlot = { screen: string; format: "banner" | "native" | "interstitial" | "app_open" | "rewarded" };
const FORBIDDEN_SCREENS = new Set([
  "chat_thread", "report_flow", "block_flow", "safety_center", "verification",
  "appeal", "appeals", "account_deletion", "login", "registration", "auth",
  "onboarding", "onboarding_age_gate", "support", "support_chat", "support_ticket",
  "ticket", "ticket_detail", "child_safety", "moderation",
]);
/** Ads never appear in conversations or safety workflows; rewarded ads are always optional. */
export function adAllowed(slot: AdSlot, ctx: { lastInterstitialMs: number | null; now?: number; minGapSec: number; isTransition: boolean }): boolean {
  if (FORBIDDEN_SCREENS.has(slot.screen)) return false;
  if (slot.format === "interstitial" || slot.format === "app_open") {
    if (!ctx.isTransition) return false;
    const now = ctx.now ?? Date.now();
    if (ctx.lastInterstitialMs !== null && now - ctx.lastInterstitialMs < ctx.minGapSec * 1000) return false;
  }
  return true;
}
export const EMERGENCY_MODES = ["normal","maintenance","read_only","registration_lock","chat_protection","security_lockdown","full_shutdown"] as const;
export type EmergencyMode = typeof EMERGENCY_MODES[number];
export type Action = "read" | "write" | "register" | "send_message" | "staff_access" | "owner_access";
export function modeAllows(mode: EmergencyMode, action: Action): boolean {
  if (action === "owner_access") return true; // recovery access always retained
  switch (mode) {
    case "normal": return true;
    case "maintenance": return action === "staff_access";
    case "read_only": return action === "read" || action === "staff_access";
    case "registration_lock": return action !== "register";
    case "chat_protection": return action !== "send_message";
    case "security_lockdown": return action === "staff_access";
    case "full_shutdown": return false;
  }
}
export function trustScore(i: { verified: boolean; ratingAvg: number | null; ratingCount: number; reportsUpheld: number; accountAgeDays: number }): number {
  let s = 50 + (i.verified ? 20 : 0) + Math.min(10, i.accountAgeDays / 30);
  if (i.ratingAvg !== null && i.ratingCount >= 3) s += (i.ratingAvg - 3) * 5;
  s -= i.reportsUpheld * 8;
  return Math.max(0, Math.min(100, Math.round(s)));
}
/** AI findings are advisory only: they can open a review case, never an automatic punishment. */
export type AiFinding = { kind: string; confidence: number; reasonCodes: string[]; evidenceRefs: string[] };
export function routeAiFinding(f: AiFinding): { action: "open_review_case" | "ignore"; priority: "low" | "normal" | "high"; autoPunish: false } {
  if (f.confidence < 0.3 || f.reasonCodes.length === 0) return { action: "ignore", priority: "low", autoPunish: false };
  return { action: "open_review_case", priority: f.confidence >= 0.85 ? "high" : "normal", autoPunish: false };
}
