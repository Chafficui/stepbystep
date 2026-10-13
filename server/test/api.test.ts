import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/index.js';
import { closePool } from '../src/db.js';
import { truncateAll } from './helpers.js';

const skipIntegration = process.env.SKIP_INTEGRATION === '1';
const d = skipIntegration ? describe.skip : describe;
if (skipIntegration) {
  console.warn(
    '[skip] Integration tests skipped: Docker unavailable and no DATABASE_URL provided.'
  );
}

let app: FastifyInstance;
const ORGA_PASSWORD = process.env.ORGA_PASSWORD!;

async function createTeam(name = 'Team A'): Promise<{ id: string; name: string; code: string }> {
  const login = await app.inject({
    method: 'POST',
    url: '/api/orga/login',
    remoteAddress: '10.0.9.1',
    payload: { password: ORGA_PASSWORD },
  });
  const { token } = login.json() as { token: string };
  const res = await app.inject({
    method: 'POST',
    url: '/api/orga/teams',
    headers: { authorization: `Bearer ${token}` },
    payload: { name },
  });
  expect(res.statusCode).toBe(201);
  return res.json() as { id: string; name: string; code: string };
}

d('API integration', () => {
  beforeAll(async () => {
    app = await buildApp();
  });
  afterAll(async () => {
    await closePool();
    await app.close();
  });
  beforeEach(async () => {
    await truncateAll();
  });

  it('join: unknown code -> 404', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/join',
      remoteAddress: '10.0.1.1',
      payload: {
        code: 'ABCD2345',
        display_name: 'Alice',
        device_id: '11111111-1111-4111-8111-111111111111',
      },
    });
    expect(res.statusCode).toBe(404);
    expect(res.json()).toEqual({ error: 'Team-Code unbekannt' });
  });

  it('join: valid code -> token works on /api/me', async () => {
    const team = await createTeam();
    const res = await app.inject({
      method: 'POST',
      url: '/api/join',
      remoteAddress: '10.0.2.1',
      payload: {
        code: team.code,
        display_name: 'Alice',
        device_id: '11111111-1111-4111-8111-111111111111',
      },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json() as { token: string; team_id: string; team_name: string; display_name: string };
    expect(body.team_name).toBe(team.name);
    expect(body.display_name).toBe('Alice');
    const me = await app.inject({
      method: 'GET',
      url: '/api/me',
      headers: { authorization: `Bearer ${body.token}` },
    });
    expect(me.statusCode).toBe(200);
    const meBody = me.json() as { team_id: string; team_name: string; team_status: string; display_name: string };
    expect(meBody).toEqual({
      team_id: team.id,
      team_name: team.name,
      team_status: 'active',
      display_name: 'Alice',
      team_photo_updated_at: null,
    });
  });

  it('join: third participant -> 409', async () => {
    const team = await createTeam();
    for (let i = 1; i <= 2; i++) {
      const res = await app.inject({
        method: 'POST',
        url: '/api/join',
        remoteAddress: '10.0.3.1',
        payload: {
          code: team.code,
          display_name: `P${i}`,
          device_id: `00000000-0000-4000-8000-00000000000${i}`,
        },
      });
      expect(res.statusCode).toBe(200);
    }
    const third = await app.inject({
      method: 'POST',
      url: '/api/join',
      remoteAddress: '10.0.3.1',
      payload: {
        code: team.code,
        display_name: 'P3',
        device_id: '00000000-0000-4000-8000-000000000003',
      },
    });
    expect(third.statusCode).toBe(409);
    expect(third.json()).toEqual({ error: 'Dieses Team ist bereits voll' });
  });

  it('join: re-join with same device_id -> new token, same participant, no duplicate', async () => {
    const team = await createTeam();
    const payload = {
      code: team.code,
      display_name: 'Alice',
      device_id: '11111111-1111-4111-8111-111111111111',
    };
    const first = await app.inject({ method: 'POST', url: '/api/join', remoteAddress: '10.0.4.1', payload });
    expect(first.statusCode).toBe(200);
    const second = await app.inject({ method: 'POST', url: '/api/join', remoteAddress: '10.0.4.1', payload });
    expect(second.statusCode).toBe(200);
    const token1 = (first.json() as { token: string }).token;
    const token2 = (second.json() as { token: string }).token;
    expect(token2).not.toBe(token1);
    const me = await app.inject({
      method: 'GET',
      url: '/api/me',
      headers: { authorization: `Bearer ${token2}` },
    });
    expect(me.statusCode).toBe(200);
    expect((me.json() as { display_name: string }).display_name).toBe('Alice');
    // Old token must no longer work.
    const old = await app.inject({
      method: 'GET',
      url: '/api/me',
      headers: { authorization: `Bearer ${token1}` },
    });
    expect(old.statusCode).toBe(401);
  });

  it('join: same code + same name from a new device reclaims the slot instead of 409', async () => {
    const team = await createTeam();
    const aliceFirst = await app.inject({
      method: 'POST',
      url: '/api/join',
      remoteAddress: '10.0.4.2',
      payload: {
        code: team.code,
        display_name: 'Alice',
        device_id: '11111111-1111-4111-8111-111111111111',
      },
    });
    expect(aliceFirst.statusCode).toBe(200);
    const bob = await app.inject({
      method: 'POST',
      url: '/api/join',
      remoteAddress: '10.0.4.2',
      payload: {
        code: team.code,
        display_name: 'Bob',
        device_id: '22222222-2222-4222-8222-222222222222',
      },
    });
    expect(bob.statusCode).toBe(200);
    const aliceToken1 = (aliceFirst.json() as { token: string }).token;

    // Team is full (2/2). Alice gets a new phone (new device_id) and rejoins
    // with the same code + name, different case — must reclaim her slot
    // rather than hit the 409 "Team ist bereits voll".
    const aliceSecond = await app.inject({
      method: 'POST',
      url: '/api/join',
      remoteAddress: '10.0.4.3',
      payload: {
        code: team.code,
        display_name: 'alice',
        device_id: '33333333-3333-4333-8333-333333333333',
      },
    });
    expect(aliceSecond.statusCode).toBe(200);
    const body = aliceSecond.json() as { token: string; display_name: string };
    expect(body.display_name).toBe('Alice');
    const aliceToken2 = body.token;

    // Old phone's token is now invalid; new phone's token works.
    const oldMe = await app.inject({
      method: 'GET',
      url: '/api/me',
      headers: { authorization: `Bearer ${aliceToken1}` },
    });
    expect(oldMe.statusCode).toBe(401);
    const newMe = await app.inject({
      method: 'GET',
      url: '/api/me',
      headers: { authorization: `Bearer ${aliceToken2}` },
    });
    expect(newMe.statusCode).toBe(200);
    expect((newMe.json() as { display_name: string }).display_name).toBe('Alice');

    // Still exactly 2 participants (reclaimed, not a third slot) and Bob
    // is untouched.
    const login = await app.inject({
      method: 'POST',
      url: '/api/orga/login',
      payload: { password: ORGA_PASSWORD },
    });
    const orgaToken = (login.json() as { token: string }).token;
    const list = await app.inject({
      method: 'GET',
      url: '/api/orga/teams',
      headers: { authorization: `Bearer ${orgaToken}` },
    });
    const teams = (list.json() as { teams: { id: string; participants: { display_name: string }[] }[] }).teams;
    const found = teams.find((t) => t.id === team.id)!;
    expect(found.participants).toHaveLength(2);
    expect(found.participants.map((p) => p.display_name).sort()).toEqual(['Alice', 'Bob']);
  });

  it('rate limit: 11 joins within a minute -> 429', async () => {
    const team = await createTeam();
    let lastCode = 0;
    for (let i = 0; i < 11; i++) {
      const res = await app.inject({
        method: 'POST',
        url: '/api/join',
        remoteAddress: '10.0.0.1',
        payload: {
          code: team.code,
          display_name: `P${i}`,
          device_id: `00000000-0000-4000-8000-00000000010${i}`,
        },
      });
      lastCode = res.statusCode;
    }
    expect(lastCode).toBe(429);
  });

  it('orga login: wrong password -> 401; correct -> token works', async () => {
    const bad = await app.inject({
      method: 'POST',
      url: '/api/orga/login',
      payload: { password: 'wrong' },
    });
    expect(bad.statusCode).toBe(401);
    const good = await app.inject({
      method: 'POST',
      url: '/api/orga/login',
      payload: { password: ORGA_PASSWORD },
    });
    expect(good.statusCode).toBe(200);
    const token = (good.json() as { token: string }).token;
    const res = await app.inject({
      method: 'GET',
      url: '/api/orga/event',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(200);
  });

  it('orga routes: participant token -> 403, no token -> 401', async () => {
    const team = await createTeam();
    const join = await app.inject({
      method: 'POST',
      url: '/api/join',
      remoteAddress: '10.0.5.1',
      payload: {
        code: team.code,
        display_name: 'Alice',
        device_id: '11111111-1111-4111-8111-111111111111',
      },
    });
    const participantToken = (join.json() as { token: string }).token;
    const asParticipant = await app.inject({
      method: 'GET',
      url: '/api/orga/event',
      headers: { authorization: `Bearer ${participantToken}` },
    });
    expect(asParticipant.statusCode).toBe(403);
    const noToken = await app.inject({ method: 'GET', url: '/api/orga/event' });
    expect(noToken.statusCode).toBe(401);
    expect(noToken.json()).toEqual({ error: 'Nicht angemeldet' });
  });

  it('GET /api/event: coordinates null pre-reveal, shown after reveal; orga always sees them', async () => {
    const team = await createTeam();
    const join = await app.inject({
      method: 'POST',
      url: '/api/join',
      remoteAddress: '10.0.6.1',
      payload: {
        code: team.code,
        display_name: 'Alice',
        device_id: '11111111-1111-4111-8111-111111111111',
      },
    });
    const token = (join.json() as { token: string }).token;

    // Set coordinates + future reveal time.
    const login = await app.inject({
      method: 'POST',
      url: '/api/orga/login',
      payload: { password: ORGA_PASSWORD },
    });
    const orgaToken = (login.json() as { token: string }).token;
    await app.inject({
      method: 'PUT',
      url: '/api/orga/event',
      headers: { authorization: `Bearer ${orgaToken}` },
      payload: {
        start_lat: 48.137,
        start_lng: 11.575,
        reveal_time: new Date(Date.now() + 3600_000).toISOString(),
      },
    });

    const pre = await app.inject({
      method: 'GET',
      url: '/api/event',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(pre.statusCode).toBe(200);
    const preBody = pre.json() as { start_lat: unknown; start_lng: unknown; end_time: string; server_now: string };
    expect(preBody.start_lat).toBeNull();
    expect(preBody.start_lng).toBeNull();
    expect(preBody.end_time).toMatch(/Z$/);
    expect(preBody.server_now).toMatch(/Z$/);

    const orgaPre = await app.inject({
      method: 'GET',
      url: '/api/orga/event',
      headers: { authorization: `Bearer ${orgaToken}` },
    });
    const orgaPreBody = orgaPre.json() as { start_lat: unknown; start_lng: unknown };
    expect(orgaPreBody.start_lat).toBe(48.137);
    expect(orgaPreBody.start_lng).toBe(11.575);

    // Move reveal_time to the past.
    await app.inject({
      method: 'PUT',
      url: '/api/orga/event',
      headers: { authorization: `Bearer ${orgaToken}` },
      payload: { reveal_time: new Date(Date.now() - 1000).toISOString() },
    });
    const post = await app.inject({
      method: 'GET',
      url: '/api/event',
      headers: { authorization: `Bearer ${token}` },
    });
    const postBody = post.json() as { start_lat: unknown; start_lng: unknown };
    expect(postBody.start_lat).toBe(48.137);
    expect(postBody.start_lng).toBe(11.575);
  });

  it('teams admin: create team returns usable code; deleting participant frees the slot', async () => {
    const login = await app.inject({
      method: 'POST',
      url: '/api/orga/login',
      payload: { password: ORGA_PASSWORD },
    });
    const orgaToken = (login.json() as { token: string }).token;
    const auth = { authorization: `Bearer ${orgaToken}` };

    const created = await app.inject({
      method: 'POST',
      url: '/api/orga/teams',
      headers: auth,
      payload: { name: 'Admin-Team' },
    });
    expect(created.statusCode).toBe(201);
    const team = created.json() as { id: string; name: string; code: string };
    expect(team.code).toMatch(/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/);

    const join = async (deviceId: string) =>
      app.inject({
        method: 'POST',
        url: '/api/join',
        remoteAddress: '10.0.7.1',
        payload: { code: team.code, display_name: 'X', device_id: deviceId },
      });
    expect((await join('11111111-1111-4111-8111-111111111111')).statusCode).toBe(200);
    expect((await join('22222222-2222-4222-8222-222222222222')).statusCode).toBe(200);
    expect((await join('33333333-3333-4333-8333-333333333333')).statusCode).toBe(409);

    const list = await app.inject({ method: 'GET', url: '/api/orga/teams', headers: auth });
    const teams = (list.json() as { teams: { id: string; participants: { id: string }[] }[] }).teams;
    const found = teams.find((t) => t.id === team.id)!;
    expect(found.participants).toHaveLength(2);

    const del = await app.inject({
      method: 'DELETE',
      url: `/api/orga/teams/${team.id}/participants/${found.participants[0].id}`,
      headers: auth,
    });
    expect(del.statusCode).toBe(204);
    expect((await join('33333333-3333-4333-8333-333333333333')).statusCode).toBe(200);
  });

  it('healthz responds ok without auth', async () => {
    const res = await app.inject({ method: 'GET', url: '/healthz' });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ status: 'ok' });
  });

  it('security headers are present', async () => {
    const res = await app.inject({ method: 'GET', url: '/healthz' });
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['referrer-policy']).toBe('no-referrer');
    expect(String(res.headers['content-security-policy'])).toContain("default-src 'self'");
  });
});
