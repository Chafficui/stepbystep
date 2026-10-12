import { randomBytes } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { query } from '../db.js';
import {
  checkOrgaPassword,
  requireOrga,
  signOrgaToken,
} from '../auth.js';
import { config } from '../config.js';
import { rateLimit } from '../ratelimit.js';
import { orgaEventUpdate } from './event.js';

interface EventFullRow {
  name: string;
  start_lat: number | null;
  start_lng: number | null;
  reveal_time: Date | null;
  start_time: Date;
  duration_h: number;
  checkin_interval_min: number;
  checkin_window_min: number;
  silence_alarm_min: number;
  speed_flag_kmh: number;
  orga_phone: string;
}

const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function randomCode(): string {
  const bytes = randomBytes(8);
  let code = '';
  for (let i = 0; i < 8; i++) code += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  return code;
}

export async function orgaRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    '/orga/login',
    { preHandler: rateLimit('orga-login') },
    async (request, reply) => {
      const parsed = z.object({ password: z.string().min(1).max(200) }).safeParse(request.body);
      if (!parsed.success) {
        void reply.code(400).send({ error: 'Ungültige Eingabe' });
        return;
      }
      if (!checkOrgaPassword(parsed.data.password, config.orgaPassword)) {
        void reply.code(401).send({ error: 'Falsches Passwort' });
        return;
      }
      const token = signOrgaToken(config.orgaSessionSecret, Math.floor(Date.now() / 1000));
      void reply.send({ token });
    }
  );

  app.addHook('onRequest', async (request, reply) => {
    if (request.url === '/api/orga/login' || request.url.startsWith('/api/orga/login?')) return;
    if (request.url.startsWith('/api/orga')) {
      await requireOrga(request, reply);
    }
  });

  app.get('/orga/event', async (_request, reply) => {
    const { rows } = await query<EventFullRow>(
      `SELECT name, start_lat, start_lng, reveal_time, start_time, duration_h,
              checkin_interval_min, checkin_window_min, silence_alarm_min, speed_flag_kmh, orga_phone
       FROM event WHERE id = 1`
    );
    if (rows.length === 0) {
      void reply.code(500).send({ error: 'Event nicht konfiguriert' });
      return;
    }
    const e = rows[0];
    void reply.send({
      name: e.name,
      start_lat: e.start_lat,
      start_lng: e.start_lng,
      reveal_time: e.reveal_time === null ? null : e.reveal_time.toISOString(),
      start_time: e.start_time.toISOString(),
      duration_h: e.duration_h,
      checkin_interval_min: e.checkin_interval_min,
      checkin_window_min: e.checkin_window_min,
      silence_alarm_min: e.silence_alarm_min,
      speed_flag_kmh: e.speed_flag_kmh,
      orga_phone: e.orga_phone,
      server_now: new Date().toISOString(),
    });
  });

  app.put('/orga/event', async (request, reply) => {
    const parsed = orgaEventUpdate.safeParse(request.body);
    if (!parsed.success) {
      void reply.code(400).send({ error: 'Ungültige Eingabe' });
      return;
    }
    const data = parsed.data;
    const fields: string[] = [];
    const params: unknown[] = [];
    for (const [key, value] of Object.entries(data)) {
      fields.push(`${key} = $${params.length + 1}`);
      params.push(value);
    }
    if (fields.length > 0) {
      params.push(1);
      await query(`UPDATE event SET ${fields.join(', ')} WHERE id = $${params.length}`, params);
    }
    const { rows } = await query<EventFullRow>(
      `SELECT name, start_lat, start_lng, reveal_time, start_time, duration_h,
              checkin_interval_min, checkin_window_min, silence_alarm_min, speed_flag_kmh, orga_phone
       FROM event WHERE id = 1`
    );
    const e = rows[0];
    void reply.send({
      name: e.name,
      start_lat: e.start_lat,
      start_lng: e.start_lng,
      reveal_time: e.reveal_time === null ? null : e.reveal_time.toISOString(),
      start_time: e.start_time.toISOString(),
      duration_h: e.duration_h,
      checkin_interval_min: e.checkin_interval_min,
      checkin_window_min: e.checkin_window_min,
      silence_alarm_min: e.silence_alarm_min,
      speed_flag_kmh: e.speed_flag_kmh,
      orga_phone: e.orga_phone,
      server_now: new Date().toISOString(),
    });
  });

  app.get('/orga/teams', async (_request, reply) => {
    const teams = await query<{ id: string; name: string; code: string; status: string }>(
      'SELECT id, name, code, status FROM team ORDER BY name'
    );
    const participants = await query<{
      team_id: string;
      id: string;
      display_name: string;
      joined_at: Date;
    }>(
      'SELECT team_id, id, display_name, joined_at FROM participant ORDER BY joined_at'
    );
    const byTeam = new Map<string, { id: string; display_name: string; joined_at: string }[]>();
    for (const p of participants.rows) {
      const list = byTeam.get(p.team_id) ?? [];
      list.push({ id: p.id, display_name: p.display_name, joined_at: p.joined_at.toISOString() });
      byTeam.set(p.team_id, list);
    }
    void reply.send({
      teams: teams.rows.map((t) => ({
        id: t.id,
        name: t.name,
        code: t.code,
        status: t.status,
        participants: byTeam.get(t.id) ?? [],
      })),
    });
  });

  app.post('/orga/teams', async (request, reply) => {
    const parsed = z.object({ name: z.string().min(1).max(60) }).safeParse(request.body);
    if (!parsed.success) {
      void reply.code(400).send({ error: 'Ungültige Eingabe' });
      return;
    }
    const name = parsed.data.name;
    for (let attempt = 0; attempt < 10; attempt++) {
      const code = randomCode();
      try {
        const { rows } = await query<{ id: string; name: string; code: string }>(
          'INSERT INTO team (name, code) VALUES ($1, $2) RETURNING id, name, code',
          [name, code]
        );
        void reply.code(201).send(rows[0]);
        return;
      } catch (err) {
        if (
          typeof err === 'object' &&
          err !== null &&
          (err as { code?: string }).code === '23505'
        ) {
          continue; // unique violation: retry with a new code
        }
        throw err;
      }
    }
    void reply.code(500).send({ error: 'Konnte Team-Code nicht erzeugen' });
  });

  app.delete('/orga/teams/:id/participants/:pid', async (request, reply) => {
    const { id, pid } = request.params as { id: string; pid: string };
    const { rowCount } = await query('DELETE FROM participant WHERE id = $1 AND team_id = $2', [
      pid,
      id,
    ]);
    if (rowCount === 0) {
      void reply.code(404).send({ error: 'Teilnehmer nicht gefunden' });
      return;
    }
    void reply.code(204).send();
  });
}
