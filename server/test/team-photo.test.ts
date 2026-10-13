import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { mkdtempSync } from 'node:fs';
import { readdir } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { truncateAll } from './helpers.js';

const skipIntegration = process.env.SKIP_INTEGRATION === '1';
const d = skipIntegration ? describe.skip : describe;
  if (skipIntegration) {
    console.warn('[skip] Feature integration tests skipped: Docker unavailable.');
  }

// UPLOAD_DIR must be set before any src module (config.ts) is imported.
const UPLOAD_DIR = mkdtempSync(path.join(os.tmpdir(), 'stepbystep-uploads-'));
process.env.UPLOAD_DIR = UPLOAD_DIR;

const { buildApp } = await import('../src/index.js');
const { query, closePool } = await import('../src/db.js');
import type { FastifyInstance } from 'fastify';

const ORGA_PASSWORD = process.env.ORGA_PASSWORD!;
const JPEG_MAGIC = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01]);
const PNG_BYTES = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.from('png-test-body'),
]);
const jpegWith = (tag: string): Buffer => Buffer.concat([JPEG_MAGIC, Buffer.from(tag)]);

function multipartBody(
  fields: Record<string, string>,
  file: { field: string; filename: string; data: Buffer }
): { payload: Buffer; contentType: string } {
  const boundary = `----vitest${Math.random().toString(36).slice(2)}`;
  const chunks: Buffer[] = [];
  for (const [name, value] of Object.entries(fields)) {
    chunks.push(
      Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; name="${name}"\r\n\r\n${value}\r\n`
      )
    );
  }
  chunks.push(
    Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="${file.field}"; filename="${file.filename}"\r\nContent-Type: application/octet-stream\r\n\r\n`
    )
  );
  chunks.push(file.data);
  chunks.push(Buffer.from(`\r\n--${boundary}--\r\n`));
  return {
    payload: Buffer.concat(chunks),
    contentType: `multipart/form-data; boundary=${boundary}`,
  };
}

interface TeamCtx {
  teamId: string;
  code: string;
  token: string;
  participantId: string;
}

let app: FastifyInstance;
let orgaToken: string;
let teamA: TeamCtx;
let teamB: TeamCtx;
let secondTokenA: string;
let secondParticipantA: string;

const auth = (token: string) => ({ authorization: `Bearer ${token}` });

async function join(code: string, name: string, device: string, ip: string) {
  const res = await app.inject({
    method: 'POST',
    url: '/api/join',
    remoteAddress: ip,
    payload: { code, display_name: name, device_id: device },
  });
  expect(res.statusCode).toBe(200);
  return (res.json() as { token: string }).token;
}

async function createTeam(name: string, device: string, ip: string): Promise<TeamCtx> {
  const created = await app.inject({
    method: 'POST',
    url: '/api/orga/teams',
    headers: auth(orgaToken),
    payload: { name },
  });
  expect(created.statusCode).toBe(201);
  const team = created.json() as { id: string; code: string };
  const token = await join(team.code, `${name}-P1`, device, ip);
  const row = await query<{ id: string }>('SELECT id FROM participant WHERE team_id = $1 LIMIT 1', [team.id]);
  return { teamId: team.id, code: team.code, token, participantId: row.rows[0].id };
}

async function uploadPhoto(token: string, id: string, data: Buffer, fields: Record<string, string> = {}) {
  const mp = multipartBody(
    { id, captured_at: new Date().toISOString(), ...fields },
    { field: 'photo', filename: 'whatever.exe', data }
  );
  return app.inject({
    method: 'POST',
    url: '/api/team-photo',
    headers: { ...auth(token), 'content-type': mp.contentType },
    payload: mp.payload,
  });
}

d('team photo + my track', () => {
  beforeAll(async () => {
    await truncateAll();
    app = await buildApp();
    const login = await app.inject({
      method: 'POST',
      url: '/api/orga/login',
      payload: { password: ORGA_PASSWORD },
    });
    expect(login.statusCode).toBe(200);
    orgaToken = (login.json() as { token: string }).token;
    teamA = await createTeam('Foto A', 'aaaaaaaa-0000-4000-8000-000000000a01', '10.2.0.1');
    teamB = await createTeam('Foto B', 'aaaaaaaa-0000-4000-8000-000000000b01', '10.2.0.2');
    secondTokenA = await join(teamA.code, 'Foto A-P2', 'aaaaaaaa-0000-4000-8000-000000000a02', '10.2.0.3');
    const row = await query<{ id: string }>(
      'SELECT id FROM participant WHERE team_id = $1 AND display_name = $2',
      [teamA.teamId, 'Foto A-P2']
    );
    secondParticipantA = row.rows[0].id;
  });
  afterAll(async () => {
    await closePool();
    await app.close();
  });

  it('rejects unauthenticated access', async () => {
    for (const [method, url] of [
      ['GET', '/api/team-photo'],
      ['POST', '/api/team-photo'],
      ['GET', '/api/my-track'],
    ] as const) {
      const res = await app.inject({ method, url });
      expect(res.statusCode).toBe(401);
    }
  });

  it('no photo yet: me shows null, GET returns 404', async () => {
    const me = await app.inject({ method: 'GET', url: '/api/me', headers: auth(teamA.token) });
    expect(me.json().team_photo_updated_at).toBeNull();
    const get = await app.inject({ method: 'GET', url: '/api/team-photo', headers: auth(teamA.token) });
    expect(get.statusCode).toBe(404);
    expect(get.json()).toEqual({ error: 'Nicht gefunden' });
  });

  it('validates input and sniffs magic bytes', async () => {
    const bad = await uploadPhoto(teamA.token, 'not-a-uuid', jpegWith('x'));
    expect(bad.statusCode).toBe(400);
    expect(bad.json()).toEqual({ error: 'Ungültige Eingabe' });
    const empty = await uploadPhoto(teamA.token, randomUUID(), Buffer.alloc(0));
    expect(empty.statusCode).toBe(400);
    const wrong = await uploadPhoto(teamA.token, randomUUID(), Buffer.from('MZ this is not an image at all'));
    expect(wrong.statusCode).toBe(415);
    expect(wrong.json()).toEqual({ error: 'Dateityp nicht erlaubt' });
    // video is not a valid team photo
    const mp4 = Buffer.concat([Buffer.from([0, 0, 0, 0x18]), Buffer.from('ftypmp42'), Buffer.alloc(16)]);
    const video = await uploadPhoto(teamA.token, randomUUID(), mp4);
    expect(video.statusCode).toBe(415);
  });

  it('upload jpg -> me shows timestamp -> GET returns same bytes; idempotent; re-take replaces', async () => {
    const id1 = randomUUID();
    const data1 = jpegWith('first-photo');
    const up = await uploadPhoto(teamA.token, id1, data1);
    expect(up.statusCode).toBe(200);
    const body = up.json() as { accepted: boolean; photo_updated_at: string };
    expect(body.accepted).toBe(true);
    expect(Number.isNaN(Date.parse(body.photo_updated_at))).toBe(false);

    const me = await app.inject({ method: 'GET', url: '/api/me', headers: auth(secondTokenA) });
    expect(me.json().team_photo_updated_at).toBe(body.photo_updated_at);

    const get = await app.inject({ method: 'GET', url: '/api/team-photo', headers: auth(secondTokenA) });
    expect(get.statusCode).toBe(200);
    expect(get.headers['content-type']).toBe('image/jpeg');
    expect(get.headers['cache-control']).toBe('private, no-cache');
    expect(get.rawPayload.equals(data1)).toBe(true);

    // idempotent re-upload of the same id: no-op, same timestamp
    const again = await uploadPhoto(teamA.token, id1, data1);
    expect(again.statusCode).toBe(200);
    expect(again.json()).toEqual(body);

    // re-take (png) replaces the photo and deletes the old file
    const id2 = randomUUID();
    const retake = await uploadPhoto(teamA.token, id2, PNG_BYTES);
    expect(retake.statusCode).toBe(200);
    const files = await readdir(UPLOAD_DIR);
    expect(files).toContain(`team-${teamA.teamId}-${id2}.png`);
    expect(files).not.toContain(`team-${teamA.teamId}-${id1}.jpg`);
    const get2 = await app.inject({ method: 'GET', url: '/api/team-photo', headers: auth(teamA.token) });
    expect(get2.headers['content-type']).toBe('image/png');
    expect(get2.rawPayload.equals(PNG_BYTES)).toBe(true);
  });

  it('other team cannot see your photo', async () => {
    const get = await app.inject({ method: 'GET', url: '/api/team-photo', headers: auth(teamB.token) });
    expect(get.statusCode).toBe(404);
    const me = await app.inject({ method: 'GET', url: '/api/me', headers: auth(teamB.token) });
    expect(me.json().team_photo_updated_at).toBeNull();
    // team B uploading never touches team A's photo
    const up = await uploadPhoto(teamB.token, randomUUID(), jpegWith('b-photo'));
    expect(up.statusCode).toBe(200);
    const getA = await app.inject({ method: 'GET', url: '/api/team-photo', headers: auth(teamA.token) });
    expect(getA.rawPayload.equals(PNG_BYTES)).toBe(true);
    const getB = await app.inject({ method: 'GET', url: '/api/team-photo', headers: auth(teamB.token) });
    expect(getB.rawPayload.equals(jpegWith('b-photo'))).toBe(true);
  });

  it('my-track returns only own team points (all participants), ascending, with since filter', async () => {
    const base = Date.parse('2026-06-01T10:00:00Z');
    const ins = async (team: TeamCtx, pid: string, minute: number, lat: number) =>
      query(
        `INSERT INTO location_point (id, team_id, participant_id, lat, lng, recorded_at)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [randomUUID(), team.teamId, pid, lat, 13, new Date(base + minute * 60_000).toISOString()]
      );
    // inserted out of order on purpose
    await ins(teamA, secondParticipantA, 3, 52.3);
    await ins(teamA, teamA.participantId, 1, 52.1);
    await ins(teamA, teamA.participantId, 2, 52.2);
    await ins(teamB, teamB.participantId, 2, 40.0);

    const res = await app.inject({ method: 'GET', url: '/api/my-track', headers: auth(teamA.token) });
    expect(res.statusCode).toBe(200);
    const pts = (res.json() as { points: { lat: number; recorded_at: string; participant_id: string }[] }).points;
    expect(pts.map((p) => p.lat)).toEqual([52.1, 52.2, 52.3]);
    expect(new Set(pts.map((p) => p.participant_id))).toEqual(new Set([teamA.participantId, secondParticipantA]));
    expect(Object.keys(pts[0]).sort()).toEqual(['lat', 'lng', 'participant_id', 'recorded_at']);

    const since = new Date(base + 2 * 60_000).toISOString();
    const filtered = await app.inject({
      method: 'GET',
      url: `/api/my-track?since=${encodeURIComponent(since)}`,
      headers: auth(teamA.token),
    });
    expect((filtered.json() as { points: { lat: number }[] }).points.map((p) => p.lat)).toEqual([52.3]);

    const badSince = await app.inject({ method: 'GET', url: '/api/my-track?since=nope', headers: auth(teamA.token) });
    expect(badSince.statusCode).toBe(400);

    const resB = await app.inject({ method: 'GET', url: '/api/my-track', headers: auth(teamB.token) });
    expect((resB.json() as { points: { lat: number }[] }).points.map((p) => p.lat)).toEqual([40.0]);
  });

  it('orga: overview/teams contain photo_updated_at; GET/DELETE team photo', async () => {
    const hdr = auth(orgaToken);
    const overview = await app.inject({ method: 'GET', url: '/api/orga/overview', headers: hdr });
    const ovTeams = (overview.json() as { teams: { id: string; photo_updated_at: string | null }[] }).teams;
    expect(ovTeams.find((t) => t.id === teamA.teamId)!.photo_updated_at).not.toBeNull();
    const list = await app.inject({ method: 'GET', url: '/api/orga/teams', headers: hdr });
    const listed = (list.json() as { teams: { id: string; photo_updated_at: string | null }[] }).teams;
    expect(listed.find((t) => t.id === teamA.teamId)!.photo_updated_at).not.toBeNull();

    const get = await app.inject({ method: 'GET', url: `/api/orga/teams/${teamA.teamId}/photo`, headers: hdr });
    expect(get.statusCode).toBe(200);
    expect(get.headers['content-type']).toBe('image/png');
    expect(get.headers['cache-control']).toBe('private, no-cache');
    expect(get.rawPayload.equals(PNG_BYTES)).toBe(true);

    const badId = await app.inject({ method: 'GET', url: '/api/orga/teams/xyz/photo', headers: hdr });
    expect(badId.statusCode).toBe(400);

    const filesBefore = await readdir(UPLOAD_DIR);
    expect(filesBefore.some((f) => f.startsWith(`team-${teamA.teamId}-`))).toBe(true);
    const del = await app.inject({ method: 'DELETE', url: `/api/orga/teams/${teamA.teamId}/photo`, headers: hdr });
    expect(del.statusCode).toBe(200);
    expect(del.json()).toEqual({ ok: true });
    const filesAfter = await readdir(UPLOAD_DIR);
    expect(filesAfter.some((f) => f.startsWith(`team-${teamA.teamId}-`))).toBe(false);

    const gone = await app.inject({ method: 'GET', url: `/api/orga/teams/${teamA.teamId}/photo`, headers: hdr });
    expect(gone.statusCode).toBe(404);
    const me = await app.inject({ method: 'GET', url: '/api/me', headers: auth(teamA.token) });
    expect(me.json().team_photo_updated_at).toBeNull();

    const unknown = await app.inject({ method: 'DELETE', url: `/api/orga/teams/${randomUUID()}/photo`, headers: hdr });
    expect(unknown.statusCode).toBe(404);

    // after the reset the team can take a new photo
    const retake = await uploadPhoto(teamA.token, randomUUID(), jpegWith('after-reset'));
    expect(retake.statusCode).toBe(200);
  });

  it('participant token cannot use orga photo routes', async () => {
    for (const method of ['GET', 'DELETE'] as const) {
      const res = await app.inject({
        method,
        url: `/api/orga/teams/${teamA.teamId}/photo`,
        headers: auth(teamA.token),
      });
      expect([401, 403]).toContain(res.statusCode);
    }
    const none = await app.inject({ method: 'GET', url: `/api/orga/teams/${teamA.teamId}/photo` });
    expect(none.statusCode).toBe(401);
  });
});
