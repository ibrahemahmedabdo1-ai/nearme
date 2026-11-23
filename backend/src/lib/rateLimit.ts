/** Fixed-window limiter. In-memory => per-instance only; for production swap the store for Upstash/Neon (documented in docs/SECURITY.md). */
export class RateLimiter {
  private hits = new Map<string, { n: number; reset: number }>();
  private max: number; private windowMs: number;
  constructor(max: number, windowMs: number) { this.max = max; this.windowMs = windowMs; }
  check(key: string, now = Date.now()): { ok: boolean; retryAfterSec: number } {
    const e = this.hits.get(key);
    if (!e || e.reset <= now) { this.hits.set(key, { n: 1, reset: now + this.windowMs }); return { ok: true, retryAfterSec: 0 }; }
    e.n++;
    return e.n > this.max ? { ok: false, retryAfterSec: Math.ceil((e.reset - now) / 1000) } : { ok: true, retryAfterSec: 0 };
  }
}
