// Provider adapters. Each returns an explicit "not_configured" result until the Owner supplies credentials -- nothing is faked as sent/connected.
export type Result<T = void> = { ok: true; data: T } | { ok: false; reason: "not_configured" | "provider_error"; detail?: string };
const nc = <T>(name: string): Result<T> => ({ ok: false, reason: "not_configured", detail: `${name} awaiting Owner credentials` });

export interface EmailProvider { send(to: string, subject: string, html: string): Promise<Result> }
export interface PushProvider { send(tokens: string[], title: string, body: string, data?: Record<string, string>): Promise<Result<{ sent: number }>> }
export interface ObjectStorage { presignUpload(key: string, mime: string, maxBytes: number): Promise<Result<{ url: string }>>; presignDownload(key: string, ttlSec: number): Promise<Result<{ url: string }>>; remove(key: string): Promise<Result> }
export interface Realtime { publish(channel: string, event: string, payload: unknown): Promise<Result>; authToken(userId: string, channels: string[]): Promise<Result<{ token: string }>> }
export interface MalwareScanner { scan(storageKey: string): Promise<Result<{ verdict: "clean" | "infected" }>> }
export interface AiModerator { analyze(kind: string, input: { text?: string; imageKey?: string }): Promise<Result<{ confidence: number; reasonCodes: string[] }>> }
export interface SocialPublisher { publish(platform: "facebook" | "instagram" | "tiktok" | "x", post: { text: string; mediaKey?: string }): Promise<Result<{ externalId: string }>> }

export function getProviders() {
  const has = (k: string) => !!process.env[k] && process.env[k] !== "none";
  return {
    email: { async send(to: string, subject: string, html: string) { if (process.env.NODE_ENV === "test") { ((globalThis as any).__mailOutbox ??= []).push({ to, subject, html }); return { ok: true, data: undefined } as Result; } return has("EMAIL_API_KEY") ? ({ ok: false, reason: "provider_error", detail: "implement vendor call in src/providers/email-<vendor>.ts" } as Result) : nc("email") } } as EmailProvider,
    push: { async send() { return has("FCM_SERVICE_ACCOUNT_JSON") ? ({ ok: false, reason: "provider_error", detail: "implement FCM HTTP v1 call" } as Result<{ sent: number }>) : nc<{ sent: number }>("fcm") } } as PushProvider,
    storage: { presignUpload: async () => nc<{ url: string }>("object-storage"), presignDownload: async () => nc<{ url: string }>("object-storage"), remove: async () => nc("object-storage") } as ObjectStorage,
    realtime: { publish: async () => nc("realtime"), authToken: async () => nc<{ token: string }>("realtime") } as Realtime,
    malware: { scan: async () => nc<{ verdict: "clean" | "infected" }>("malware-scan") } as MalwareScanner,
    ai: { analyze: async () => nc<{ confidence: number; reasonCodes: string[] }>("ai") } as AiModerator,
    social: { publish: async () => nc<{ externalId: string }>("social-api") } as SocialPublisher,
  };
}
