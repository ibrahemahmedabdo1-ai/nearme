export const TEMP_OPTIONS = { off: 0, "24h": 86_400_000, "7d": 604_800_000, "30d": 2_592_000_000 } as const;
export type TempMode = keyof typeof TEMP_OPTIONS;
/** Temporary messages expire N after being READ by the recipient. Unread messages never expire. */
export function expiresAt(mode: TempMode, readAtMs: number | null): number | null {
  return mode === "off" || readAtMs === null ? null : readAtMs + TEMP_OPTIONS[mode];
}
export const isExpired = (exp: number | null, now = Date.now()) => exp !== null && exp <= now;
/** "Delete for both" is allowed only for the sender, within the Owner-configured window. */
export function canDeleteForBoth(sentAtMs: number, senderId: string, actorId: string, windowMin: number, now = Date.now()) {
  return senderId === actorId && windowMin > 0 && now - sentAtMs <= windowMin * 60_000;
}
const BLOCKED_EXT = new Set(["exe","msi","bat","cmd","com","scr","js","jse","vbs","vbe","wsf","ps1","sh","apk","aab","dll","jar","lnk","reg","hta","iso","dmg","pkg","app","py","php","svg","html","htm"]);
const ALLOWED = new Map<string, string>([["jpg","image/jpeg"],["jpeg","image/jpeg"],["png","image/png"],["webp","image/webp"],["gif","image/gif"],["pdf","application/pdf"],["txt","text/plain"],["docx","application/vnd.openxmlformats-officedocument.wordprocessingml.document"]]);
export type UploadVerdict = { ok: true; ext: string } | { ok: false; reason: string };
export function checkUpload(name: string, mime: string, size: number, maxBytes: number, head: Uint8Array): UploadVerdict {
  const parts = name.toLowerCase().split(".");
  if (parts.length > 2 && parts.slice(1, -1).some(p => BLOCKED_EXT.has(p))) return { ok: false, reason: "double_extension" };
  const ext = parts.length > 1 ? parts.at(-1)! : "";
  if (BLOCKED_EXT.has(ext)) return { ok: false, reason: "blocked_type" };
  if (!ALLOWED.has(ext) || ALLOWED.get(ext) !== mime) return { ok: false, reason: "type_not_allowed" };
  if (size <= 0 || size > maxBytes) return { ok: false, reason: "size_limit" };
  const h = (n: number) => Buffer.from(head.slice(0, n)).toString("latin1");
  const sig = { jpg: h(2) === "\xff\xd8", jpeg: h(2) === "\xff\xd8", png: h(4) === "\x89PNG", gif: h(3) === "GIF", webp: h(4) === "RIFF", pdf: h(4) === "%PDF", docx: h(2) === "PK", txt: true } as Record<string, boolean>;
  if (!sig[ext]) return { ok: false, reason: "content_mismatch" };
  return { ok: true, ext };
}
