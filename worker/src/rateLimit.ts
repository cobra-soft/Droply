import { DurableObject } from 'cloudflare:workers';
import { Env, RateLimiterStub } from './types';

/**
 * Fixed-window rate limiter backed by a Durable Object.
 *
 * A plain in-memory Map in the Worker does NOT work for this: Workers can run
 * many isolates in parallel (different PoPs, cold starts), so a module-level
 * Map gives no real cross-request guarantee. A Durable Object is pinned to a
 * single location per id, so `check()` calls for the same key are serialized
 * and see consistent state.
 */
export class RateLimiterDO extends DurableObject<Env> {
  async check(windowMs: number, maxHits: number): Promise<{ allowed: boolean; resetIn: number }> {
    const now = Date.now();
    const hits = ((await this.ctx.storage.get<number[]>('hits')) ?? []).filter((t) => now - t < windowMs);

    if (hits.length >= maxHits) {
      const resetIn = Math.max(0, hits[0] + windowMs - now);
      return { allowed: false, resetIn };
    }

    hits.push(now);
    await this.ctx.storage.put('hits', hits);
    // Let the DO evict itself once the window has fully elapsed, so idle
    // limiters don't sit in storage forever.
    await this.ctx.storage.setAlarm(now + windowMs);
    return { allowed: true, resetIn: 0 };
  }

  async alarm(): Promise<void> {
    await this.ctx.storage.deleteAll();
  }
}

/** Helper for routes: checks a per-IP limit identified by `bucket`. */
export async function checkRateLimit(
  env: Env,
  clientIP: string,
  bucket: string,
  windowMs: number,
  maxHits: number,
): Promise<{ allowed: boolean; resetIn: number }> {
  const id = env.RATE_LIMITER.idFromName(`${bucket}:${clientIP}`);
  const stub = env.RATE_LIMITER.get(id) as unknown as RateLimiterStub;
  return stub.check(windowMs, maxHits);
}
