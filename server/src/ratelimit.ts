import type { FastifyReply, FastifyRequest } from 'fastify';

// In-memory fixed-window rate limiter, keyed by "ip:route".
const WINDOW_MS = 60_000;
const DEFAULT_LIMIT = 10;

const buckets = new Map<string, { count: number; windowStart: number }>();

function cleanup(now: number): void {
  for (const [key, bucket] of buckets) {
    if (now - bucket.windowStart >= WINDOW_MS) buckets.delete(key);
  }
}

/**
 * preHandler hook factory for a fixed-window rate limiter.
 * key: route identifier (e.g. "join"), limit: max requests per minute.
 */
export function rateLimit(key: string, limit: number = DEFAULT_LIMIT) {
  return async function handler(request: FastifyRequest, reply: FastifyReply): Promise<void> {
    const now = Date.now();
    const ip = request.ip;
    const bucketKey = `${ip}:${key}`;
    let bucket = buckets.get(bucketKey);
    if (bucket === undefined || now - bucket.windowStart >= WINDOW_MS) {
      if (buckets.size > 10_000) cleanup(now);
      bucket = { count: 0, windowStart: now };
      buckets.set(bucketKey, bucket);
    }
    bucket.count += 1;
    if (bucket.count > limit) {
      void reply.code(429).send({ error: 'Too many requests' });
    }
  };
}
