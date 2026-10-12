import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { mkdtempSync } from 'node:fs';
import { readdir, stat } from 'node:fs/promises';
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
  token: string;
  participantId: string;
}

let app: FastifyInstance;

async function loginOrga(): Promise<string> {
  const res = await app.inject({
    method: 'POST',
    url: '/api/orga/login',
    payload: { password: ORGA_PASSWORD },
  });
  expect(res.statusCode).toBe(200);
  return (res.json() as { token: string }).token;
}

async function createJoinedTeam(name: string, deviceSuffix: string): Promise<TeamCtx> {
  const orgaToken = await loginOrga();
  const created = await app.inject({
    method: 'POST',
    url: '/api/orga/teams',
    headers: { authorization: `Bearer ${orgaToken}` },
    payload: { name },
  });
  expect(created.statusCode).toBe(201);
  const team = created.json() as { id: string; name: string; code: string };
  const join = await app.inject({
    method: 'POST',
    url: '/api/join',
    remoteAddress: `10.1.${deviceSuffix.charCodeAt(0)}.${deviceSuffix.charCodeAt(1)}`,
    payload: {
      code: team.code,
      display_name: `${name}-P1`,
      device_id: `aaaaaaaa-0000-4000-8000-0000000000${deviceSuffix}`,
    },
  });
  expect(join.statusCode).toBe(200);
  const joined = join.json() as { token: string };
  const row = await query<{ id: string }>(
    'SELECT id FROM participant WHERE team_id = $1 LIMIT 1',
    [team.id]
  );
  return { teamId: team.id, token: joined.token, participantId: row.rows[0].id };
}

d('feature routes', () => {
  beforeAll(async () => {
    app = await buildApp();
  });
  afterAll(async () => {
    await closePool();
    await app.close();
  });
  beforeEach(async () => {
    await import('./helpers.js').then((h) => h.truncateAll());
  });

  it('team isolation: foreign point ids are not accepted, smuggled team_id ignored, foreign checkin id -> 403', async () => {
    const teamA = await createJoinedTeam('Iso A', '11');
    const teamB = await createJoinedTeam('Iso B', '22');
    const foreignPointId = randomUUID();
    const bPoint = {
      id: foreignPointId,
      lat: 52,
      lng: 13,
      recorded_at: new Date().toISOString(),
    };
    await query(
      `INSERT INTO location_point (id, team_id, participant_id, lat, lng, recorded_at)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [foreignPointId, teamB.teamId, teamB.participantId, bPoint.lat, bPoint.lng, bPoint.recorded_at]
    );
    const ownPointId = randomUUID();
    const batch = await app.inject({
      method: 'POST',
      url: '/api/points/batch',
      headers: { authorization: `Bearer ${teamA.token}` },
      payload: { points: [bPoint, { ...bPoint, id: ownPointId, team_id: teamB.teamId }] },
    });
    expect(batch.statusCode).toBe(200);
    const accepted = (batch.json() as { accepted: string[] }).accepted;
    expect(accepted).toEqual([ownPointId]);

    // Smuggled team_id on alerts is ignored: alert belongs to team A.
    const alert = await app.inject({
      method: 'POST',
      url: '/api/alerts',
      headers: { authorization: `Bearer ${teamA.token}` },
      payload: {
        id: randomUUID(),
        type: 'sos',
        created_at: new Date().toISOString(),
        team_id: teamB.teamId,
      },
    });
    expect(alert.statusCode).toBe(200);
    const alertRow = await query<{ team_id: string }>('SELECT team_id FROM alert');
    expect(alertRow.rows[0].team_id).toBe(teamA.teamId);

    // Foreign checkin id -> 403, no file written.
    const foreignCheckinId = randomUUID();
    await query(
      `INSERT INTO checkin (id, team_id, participant_id, slot, media_path, media_type, captured_at)
       VALUES ($1, $2, $3, 0, 'dummy.jpg', 'photo', now())`,
      [foreignCheckinId, teamB.teamId, teamB.participantId]
    );
    const mp = multipartBody(
      { id: foreignCheckinId, captured_at: new Date().toISOString(), media_type: 'photo' },
      { field: 'file', filename: 'x.jpg', data: JPEG_MAGIC }
    );
    const checkin = await app.inject({
      method: 'POST',
      url: '/api/checkins',
      headers: { authorization: `Bearer ${teamA.token}`, 'content-type': mp.contentType },
      payload: mp.payload,
    });
    expect(checkin.statusCode).toBe(403);
    expect(checkin.json()).toEqual({ error: 'Unerlaubt' });
  });

  it('orga routes are not reachable with a participant token', async () => {
    const teamA = await createJoinedTeam('Orga-Guard', '11');
    for (const url of ['/api/orga/overview', `/api/orga/track?team=${teamA.teamId}`]) {
      const res = await app.inject({
        method: 'GET',
        url,
        headers: { authorization: `Bearer ${teamA.token}` },
      });
      expect(res.statusCode).toBe(403);
    }
  });

  it('my-rank: no distance_km in payload, rank/team_count correct', async () => {
    const teamA = await createJoinedTeam('Rank A', '11');
    const teamB = await createJoinedTeam('Rank B', '22');
    await app.inject({
      method: 'PUT',
      url: '/api/orga/event',
      headers: { authorization: `Bearer ${await loginOrga()}` },
      payload: { start_lat: 52.52, start_lng: 13.405, start_time: new Date(Date.now() - 3600_000).toISOString() },
    });
    const pid = await query<{ id: string }>(
      'SELECT id FROM participant WHERE team_id = $1 LIMIT 1',
      [teamB.teamId]
    );
    await query(
      `INSERT INTO location_point (id, team_id, participant_id, lat, lng, recorded_at) VALUES ($1,$2,$3,$4,$5,now())`,
      [randomUUID(), teamA.teamId, teamA.participantId, 52.52, 13.405]
    );
    await query(
      `INSERT INTO location_point (id, team_id, participant_id, lat, lng, recorded_at) VALUES ($1,$2,$3,$4,$5,now())`,
      [randomUUID(), teamB.teamId, pid.rows[0].id, 52.6, 13.405]
    );
    const compute = await app.inject({
      method: 'POST',
      url: '/api/orga/ranking',
      headers: { authorization: `Bearer ${await loginOrga()}` },
    });
    expect(compute.statusCode).toBe(200);
    const rank = await app.inject({
      method: 'GET',
      url: '/api/my-rank',
      headers: { authorization: `Bearer ${teamA.token}` },
    });
    expect(rank.statusCode).toBe(200);
    const body = rank.json() as Record<string, unknown>;
    expect(Object.keys(body)).not.toContain('distance_km');
    expect(body.rank).toBe(2); // A is at the start point -> shortest distance
    expect(body.team_count).toBe(2);
    expect(typeof body.computed_at).toBe('string');
  });

  it('idempotency: batch, checkin and alert repeats create no duplicates', async () => {
    const teamA = await createJoinedTeam('Idem A', '11');
    const pointId = randomUUID();
    const payload = {
      points: [{ id: pointId, lat: 52, lng: 13, recorded_at: new Date().toISOString() }],
    };
    const first = await app.inject({
      method: 'POST',
      url: '/api/points/batch',
      headers: { authorization: `Bearer ${teamA.token}` },
      payload,
    });
    expect(first.statusCode).toBe(200);
    expect((first.json() as { accepted: string[] }).accepted).toEqual([pointId]);
    const second = await app.inject({
      method: 'POST',
      url: '/api/points/batch',
      headers: { authorization: `Bearer ${teamA.token}` },
      payload,
    });
    expect((second.json() as { accepted: string[] }).accepted).toEqual([pointId]);
    const count = await query<{ count: string }>(
      'SELECT count(*) AS count FROM location_point WHERE id = $1',
      [pointId]
    );
    expect(parseInt(count.rows[0].count, 10)).toBe(1);

    const checkinId = randomUUID();
    const mp = multipartBody(
      { id: checkinId, captured_at: new Date().toISOString(), media_type: 'photo' },
      { field: 'file', filename: 'selfie.jpg', data: JPEG_MAGIC }
    );
    for (let i = 0; i < 2; i++) {
      const res = await app.inject({
        method: 'POST',
        url: '/api/checkins',
        headers: { authorization: `Bearer ${teamA.token}`, 'content-type': mp.contentType },
        payload: mp.payload,
      });
      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({ accepted: true, slot: 0 });
    }
    const rows = await query('SELECT id FROM checkin WHERE id = $1', [checkinId]);
    expect(rows.rows).toHaveLength(1);
    const files = (await readdir(UPLOAD_DIR)).filter((f) => f.startsWith(checkinId));
    expect(files).toEqual([`${checkinId}.jpg`]);

    const alertId = randomUUID();
    for (let i = 0; i < 2; i++) {
      const res = await app.inject({
        method: 'POST',
        url: '/api/alerts',
        headers: { authorization: `Bearer ${teamA.token}` },
        payload: { id: alertId, type: 'sos', created_at: new Date().toISOString() },
      });
      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({ accepted: true });
    }
    const alerts = await query('SELECT id FROM alert WHERE id = $1', [alertId]);
    expect(alerts.rows).toHaveLength(1);
  });

  it('upload rejection: wrong magic bytes -> 415, client filename never used for storage', async () => {
    const teamA = await createJoinedTeam('Upload A', '11');
    const textJpg = multipartBody(
      { id: randomUUID(), captured_at: new Date().toISOString(), media_type: 'photo' },
      { field: 'file', filename: 'not-really.jpg', data: Buffer.from('hello world, not an image') }
    );
    const res = await app.inject({
      method: 'POST',
      url: '/api/checkins',
      headers: { authorization: `Bearer ${teamA.token}`, 'content-type': textJpg.contentType },
      payload: textJpg.payload,
    });
    expect(res.statusCode).toBe(415);
    expect(res.json()).toEqual({ error: 'Dateityp nicht erlaubt' });

    // Valid JPEG but traversal-style filename: stored as <uuid>.jpg inside UPLOAD_DIR.
    const checkinId = randomUUID();
    const evil = multipartBody(
      { id: checkinId, captured_at: new Date().toISOString(), media_type: 'photo' },
      { field: 'file', filename: '../../evil.jpg', data: JPEG_MAGIC }
    );
    const ok = await app.inject({
      method: 'POST',
      url: '/api/checkins',
      headers: { authorization: `Bearer ${teamA.token}`, 'content-type': evil.contentType },
      payload: evil.payload,
    });
    expect(ok.statusCode).toBe(200);
    const stored = path.join(UPLOAD_DIR, `${checkinId}.jpg`);
    expect((await stat(stored)).size).toBe(JPEG_MAGIC.length);
    // No file escaped the upload dir.
    const escaped = path.join(UPLOAD_DIR, '..', 'evil.jpg');
    await expect(stat(escaped)).rejects.toThrow();

    // Media streaming with range request.
    const orgaToken = await loginOrga();
    const full = await app.inject({
      method: 'GET',
      url: `/api/orga/media/${checkinId}`,
      headers: { authorization: `Bearer ${orgaToken}` },
    });
    expect(full.statusCode).toBe(200);
    expect(full.headers['content-type']).toBe('image/jpeg');
    expect(full.body).toEqual(JPEG_MAGIC.toString('latin1'));
    const part = await app.inject({
      method: 'GET',
      url: `/api/orga/media/${checkinId}`,
      headers: { authorization: `Bearer ${orgaToken}`, range: 'bytes=0-2' },
    });
    expect(part.statusCode).toBe(206);
    expect(part.headers['content-range']).toBe(`bytes 0-2/${JPEG_MAGIC.length}`);
  });

  it('slot computation: floor semantics at slot boundaries', async () => {
    const teamA = await createJoinedTeam('Slot A', '11');
    await query("UPDATE event SET start_time = '2024-01-01T00:00:00Z', checkin_interval_min = 10");
    const atBoundary = new Date('2024-01-01T00:20:00Z'); // slot 2 exactly
    const afterBoundary = new Date('2024-01-01T00:20:01Z'); // still slot 2
    const beforeBoundary = new Date('2024-01-01T00:19:59Z'); // slot 1
    const cases: [Date, number][] = [
      [atBoundary, 2],
      [afterBoundary, 2],
      [beforeBoundary, 1],
    ];
    for (const [captured, expectedSlot] of cases) {
      const mp = multipartBody(
        { id: randomUUID(), captured_at: captured.toISOString(), media_type: 'photo' },
        { field: 'file', filename: 'c.jpg', data: JPEG_MAGIC }
      );
      const res = await app.inject({
        method: 'POST',
        url: '/api/checkins',
        headers: { authorization: `Bearer ${teamA.token}`, 'content-type': mp.contentType },
        payload: mp.payload,
      });
      expect(res.statusCode).toBe(200);
      expect((res.json() as { slot: number }).slot).toBe(expectedSlot);
    }
  });

  it('ranking: farther last point ranks 1; points after end_time are ignored', async () => {
    const teamA = await createJoinedTeam('Race A', '11');
    const teamB = await createJoinedTeam('Race B', '22');
    await app.inject({
      method: 'PUT',
      url: '/api/orga/event',
      headers: { authorization: `Bearer ${await loginOrga()}` },
      payload: {
        start_lat: 52.52,
        start_lng: 13.405,
        start_time: new Date(Date.now() - 2 * 3600_000).toISOString(),
        duration_h: 1, // end_time = 1h ago
      },
    });
    const pidB = await query<{ id: string }>(
      'SELECT id FROM participant WHERE team_id = $1 LIMIT 1',
      [teamB.teamId]
    );
    // Team A: near point before end + far point after end (must be ignored).
    await query(
      `INSERT INTO location_point (id, team_id, participant_id, lat, lng, recorded_at)
       VALUES ($1,$2,$3,52.521,13.406,$4), ($5,$6,$7,60,20,$8)`,
      [
        randomUUID(), teamA.teamId, teamA.participantId, new Date(Date.now() - 90 * 60_000).toISOString(),
        randomUUID(), teamA.teamId, teamA.participantId, new Date(Date.now() - 30 * 60_000).toISOString(),
      ]
    );
    // Team B: far point before end.
    await query(
      `INSERT INTO location_point (id, team_id, participant_id, lat, lng, recorded_at)
       VALUES ($1,$2,$3,52.6,13.405,$4)`,
      [randomUUID(), teamB.teamId, pidB.rows[0].id, new Date(Date.now() - 90 * 60_000).toISOString()]
    );
    const res = await app.inject({
      method: 'POST',
      url: '/api/orga/ranking',
      headers: { authorization: `Bearer ${await loginOrga()}` },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json() as {
      computed_at: string;
      entries: { team_id: string; team_name: string; rank: number; distance_km: number }[];
    };
    const entryA = body.entries.find((e) => e.team_id === teamA.teamId)!;
    const entryB = body.entries.find((e) => e.team_id === teamB.teamId)!;
    expect(entryB.rank).toBe(1);
    expect(entryA.rank).toBe(2);
    expect(entryA.distance_km).toBeLessThan(1);

    const latest = await app.inject({
      method: 'GET',
      url: '/api/orga/ranking',
      headers: { authorization: `Bearer ${await loginOrga()}` },
    });
    expect(latest.statusCode).toBe(200);
    expect((latest.json() as { computed_at: string }).computed_at).toBe(body.computed_at);
  });

  it('alerts: sos + abort; abort marks team aborted; resolve works; overview lists alerts', async () => {
    const teamA = await createJoinedTeam('Alert A', '11');
    const orgaToken = await loginOrga();
    const sosId = randomUUID();
    const abortId = randomUUID();
    const sos = await app.inject({
      method: 'POST',
      url: '/api/alerts',
      headers: { authorization: `Bearer ${teamA.token}` },
      payload: { id: sosId, type: 'sos', lat: 52, lng: 13, created_at: new Date().toISOString() },
    });
    expect(sos.statusCode).toBe(200);
    const abort = await app.inject({
      method: 'POST',
      url: '/api/alerts',
      headers: { authorization: `Bearer ${teamA.token}` },
      payload: { id: abortId, type: 'abort', created_at: new Date().toISOString(), note: 'abgebrochen' },
    });
    expect(abort.statusCode).toBe(200);
    const status = await query<{ status: string }>('SELECT status FROM team WHERE id = $1', [
      teamA.teamId,
    ]);
    expect(status.rows[0].status).toBe('aborted');

    const overview = await app.inject({
      method: 'GET',
      url: '/api/orga/overview',
      headers: { authorization: `Bearer ${orgaToken}` },
    });
    expect(overview.statusCode).toBe(200);
    const alerts = (overview.json() as { alerts: { id: string; resolved: boolean; team_name: string }[] }).alerts;
    expect(alerts.map((a) => a.id)).toEqual([abortId, sosId]); // newest first
    expect(alerts.every((a) => a.team_name === 'Alert A' && a.resolved === false)).toBe(true);

    const resolve = await app.inject({
      method: 'POST',
      url: `/api/orga/alerts/${sosId}/resolve`,
      headers: { authorization: `Bearer ${orgaToken}` },
    });
    expect(resolve.statusCode).toBe(200);
    expect(resolve.json()).toEqual({ ok: true });
    const after = await query<{ resolved_at: Date | null }>(
      'SELECT resolved_at FROM alert WHERE id = $1',
      [sosId]
    );
    expect(after.rows[0].resolved_at).not.toBeNull();
  });

  it('overview hints: silence, checkin overdue and speeding', async () => {
    const teamA = await createJoinedTeam('Hint A', '11');
    const teamB = await createJoinedTeam('Hint B', '22');
    const teamC = await createJoinedTeam('Hint C', '33');
    await app.inject({
      method: 'PUT',
      url: '/api/orga/event',
      headers: { authorization: `Bearer ${await loginOrga()}` },
      payload: {
        start_lat: 52.52,
        start_lng: 13.405,
        start_time: new Date(Date.now() - 41 * 60_000).toISOString(),
        silence_alarm_min: 10,
        checkin_interval_min: 30,
        checkin_window_min: 10,
      },
    });
    // Team A: only an old point -> silent.
    await query(
      `INSERT INTO location_point (id, team_id, participant_id, lat, lng, recorded_at)
       VALUES ($1,$2,$3,52.52,13.405,$4)`,
      [randomUUID(), teamA.teamId, teamA.participantId, new Date(Date.now() - 20 * 60_000).toISOString()]
    );
    // Team B: fresh point + check-in in the due slot (slot 1) -> not silent, not overdue.
    await query(
      `INSERT INTO location_point (id, team_id, participant_id, lat, lng, recorded_at)
       VALUES ($1,$2,$3,52.52,13.405,now())`,
      [randomUUID(), teamB.teamId, teamB.participantId]
    );
    await query(
      `INSERT INTO checkin (id, team_id, participant_id, slot, media_path, media_type, captured_at)
       VALUES ($1,$2,$3,1,'b.jpg','photo',now())`,
      [randomUUID(), teamB.teamId, teamB.participantId]
    );
    // Team C: speeding pair (>12 km/h over ~15 min); team B's analogous pair has accuracy 150 and is ignored.
    await query(
      `INSERT INTO location_point (id, team_id, participant_id, lat, lng, accuracy, recorded_at) VALUES
       ($1,$2,$3,52.50,13.405,5,$4), ($5,$6,$7,52.60,13.405,5,$8)`,
      [
        randomUUID(), teamC.teamId, teamC.participantId, new Date(Date.now() - 20 * 60_000).toISOString(),
        randomUUID(), teamC.teamId, teamC.participantId, new Date(Date.now() - 5 * 60_000).toISOString(),
      ]
    );
    await query(
      `INSERT INTO location_point (id, team_id, participant_id, lat, lng, accuracy, recorded_at) VALUES
       ($1,$2,$3,52.50,13.405,150,$4), ($5,$6,$7,52.60,13.405,150,$8)`,
      [
        randomUUID(), teamB.teamId, teamB.participantId, new Date(Date.now() - 20 * 60_000).toISOString(),
        randomUUID(), teamB.teamId, teamB.participantId, new Date(Date.now() - 5 * 60_000).toISOString(),
      ]
    );
    const overview = await app.inject({
      method: 'GET',
      url: '/api/orga/overview',
      headers: { authorization: `Bearer ${await loginOrga()}` },
    });
    expect(overview.statusCode).toBe(200);
    const teams = (overview.json() as { teams: { id: string; hints: Record<string, boolean> }[] }).teams;
    const byId = new Map(teams.map((t) => [t.id, t.hints]));
    expect(byId.get(teamA.teamId)).toMatchObject({ silent: true, checkin_overdue: true, speeding: false });
    expect(byId.get(teamB.teamId)).toMatchObject({ silent: false, checkin_overdue: false, speeding: false });
    expect(byId.get(teamC.teamId)).toMatchObject({ silent: false, checkin_overdue: true, speeding: true });
  });
});