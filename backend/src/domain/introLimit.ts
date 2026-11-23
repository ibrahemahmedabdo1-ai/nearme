/** Intro rule: until the recipient replies, the sender may send at most 3 messages of ANY type
 *  (text, image, gif, sticker, file, location) across ALL requests between the same pair. */
export const INTRO_LIMIT = 3;
export type Msg = { senderId: string; recipientId: string; kind: string; deleted?: boolean };
export type IntroDecision = { allowed: boolean; remaining: number; reason?: "limit_reached" | "blocked" | "request_rejected" };

export function evaluateIntro(history: Msg[], sender: string, recipient: string,
  opts: { blocked?: boolean; rejected?: boolean } = {}): IntroDecision {
  if (opts.blocked) return { allowed: false, remaining: 0, reason: "blocked" };
  if (opts.rejected) return { allowed: false, remaining: 0, reason: "request_rejected" };
  // Pair-wide scan (not per request) so opening a new request cannot reset the counter. Deleted messages still count.
  const pair = history.filter(m => (m.senderId === sender && m.recipientId === recipient) || (m.senderId === recipient && m.recipientId === sender));
  let sent = 0;
  for (const m of pair) { if (m.senderId === recipient) sent = 0; else sent++; }
  return sent >= INTRO_LIMIT ? { allowed: false, remaining: 0, reason: "limit_reached" } : { allowed: true, remaining: INTRO_LIMIT - sent };
}
