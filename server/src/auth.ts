import { createHash, createHmac, timingSafeEqual } from 'node:crypto';
import type { FastifyReply, FastifyRequest } from 'fastify';
import { query } from './db.js';
import { config } from './config.js';

export interface ParticipantRow {
  id: string;
  team_id: string;
  display_name: string;
}

export function sha256Hex(value: string): string {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

function getBearer(request: FastifyRequest): string | null {
  const header = request.headers.authorization;
  if (header === undefined || !header.startsWith('Bearer ')) return null;
  const token = header.slice(7).trim();
  return token.length > 0 ? token : null;
}

/** Fastify preHandler hook: requires a valid participant token. */
export async function requireParticipant(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  const token = getBearer(request);
  if (token === null) {
    void reply.code(401).send({ error: 'Nicht angemeldet' });
    return;
  }
  const { rows } = await query<ParticipantRow & { device_id: string }>(
    'SELECT id, team_id, display_name, device_id FROM participant WHERE token_hash = $1',
    [sha256Hex(token)]
  );
  if (rows.length === 0) {
    void reply.code(401).send({ error: 'Nicht angemeldet' });
    return;
  }
  (request as FastifyRequest & { participant?: ParticipantRow }).participant = rows[0];
}

export function getParticipant(request: FastifyRequest): ParticipantRow {
  return (request as FastifyRequest & { participant?: ParticipantRow }).participant!;
}

// ---- Orga session tokens (stateless HMAC-SHA256) ----

interface OrgaPayload {
  role: string;
  exp: number;
}

function b64url(buf: Buffer): string {
  return buf.toString('base64url');
}

export function signOrgaToken(secret: string, nowSeconds: number, ttlSeconds = 24 * 3600): string {
  const payload: OrgaPayload = { role: 'orga', exp: nowSeconds + ttlSeconds };
  const body = b64url(Buffer.from(JSON.stringify(payload), 'utf8'));
  const sig = b64url(createHmac('sha256', secret).update(body).digest());
  return `${body}.${sig}`;
}

export function verifyOrgaToken(token: string, secret: string, nowSeconds: number): OrgaPayload | null {
  const dot = token.indexOf('.');
  if (dot <= 0) return null;
  const body = token.slice(0, dot);
  const sig = token.slice(dot + 1);
  const expected = createHmac('sha256', secret).update(body).digest();
  let given: Buffer;
  try {
    given = Buffer.from(sig, 'base64url');
  } catch {
    return null;
  }
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) return null;
  let payload: OrgaPayload;
  try {
    payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8')) as OrgaPayload;
  } catch {
    return null;
  }
  if (payload.role !== 'orga' || typeof payload.exp !== 'number') return null;
  if (payload.exp <= nowSeconds) return null;
  return payload;
}

export function isParticipantToken(token: string): boolean {
  // A participant token is a 64-char hex string (sha256 of a random token is what we store,
  // but the presented token itself is 64 hex chars).
  return /^[0-9a-f]{64}$/.test(token);
}

/** Fastify preHandler hook: requires a valid orga session token. */
export async function requireOrga(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const token = getBearer(request);
  if (token === null) {
    void reply.code(401).send({ error: 'Nicht angemeldet' });
    return;
  }
  if (isParticipantToken(token)) {
    void reply.code(403).send({ error: 'Zugriff verweigert' });
    return;
  }
  if (verifyOrgaToken(token, config.orgaSessionSecret, Math.floor(Date.now() / 1000)) === null) {
    void reply.code(401).send({ error: 'Nicht angemeldet' });
    return;
  }
}

/** Orga login check: constant-time comparison of sha256 digests. */
export function checkOrgaPassword(presented: string, expected: string): boolean {
  const a = createHash('sha256').update(presented, 'utf8').digest();
  const b = createHash('sha256').update(expected, 'utf8').digest();
  return timingSafeEqual(a, b);
}
