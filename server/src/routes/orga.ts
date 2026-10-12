import { randomBytes } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import path from 'node:path';
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
import { haversineKm } from '../geo.js';
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
      void reply.code(400).send({ error: 'Ungültige Eingabe: ' + parsed.error.issues.map((i) => i.path.join('.')).join(', ') });
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

  // ------------------------------------------------------------------
  // Feature routes (live tracking, check-ins, alerts, ranking, media).
  // All of these are covered by the requireOrga onRequest hook above.
  // ------------------------------------------------------------------

  const uuid = z.string().uuid();

  interface OverviewEventRow {
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

  /** true if any >=10 min window of points averages more than the speed threshold. */
  function flagSpeeding(
    points: { lat: number; lng: number; recorded_at: Date }[],
    limitKmh: number
  ): boolean {
    // points are ordered oldest -> newest. i is the oldest index that can start a
    // >=10 min window ending at j; advance it while the window stays >=10 min.
    let start = 0;
    for (let j = 1; j < points.length; j++) {
      while (
        start < j &&
        points[j].recorded_at.getTime() - points[start].recorded_at.getTime() >= 10 * 60_000
      ) {
        // every pair (k, j) with k >= start spans >=10 min: check each window ending at j
        for (let k = start; k < j; k++) {
          const dtMs = points[j].recorded_at.getTime() - points[k].recorded_at.getTime();
          const km = haversineKm(points[k].lat, points[k].lng, points[j].lat, points[j].lng);
          if (km / (dtMs / 3_600_000) > limitKmh) return true;
        }
        start++;
      }
    }
    return false;
  }

  app.get('/orga/overview', async (_request, reply) => {
    const evRes = await query<OverviewEventRow>(
      `SELECT name, start_lat, start_lng, reveal_time, start_time, duration_h,
              checkin_interval_min, checkin_window_min, silence_alarm_min, speed_flag_kmh, orga_phone
       FROM event WHERE id = 1`
    );
    if (evRes.rows.length === 0) {
      void reply.code(500).send({ error: 'Event nicht konfiguriert' });
      return;
    }
    const ev = evRes.rows[0];
    const now = new Date();
    const endTime = new Date(ev.start_time.getTime() + ev.duration_h * 3600_000);
    const eventRunning = now.getTime() < endTime.getTime();

    const teams = await query<{ id: string; name: string; code: string; status: string }>(
      'SELECT id, name, code, status FROM team ORDER BY name'
    );
    const lastPoints = await query<{
      team_id: string;
      lat: number;
      lng: number;
      recorded_at: Date;
      accuracy: number | null;
      battery: number | null;
    }>(
      `SELECT DISTINCT ON (team_id) team_id, lat, lng, recorded_at, accuracy, battery
       FROM location_point ORDER BY team_id, recorded_at DESC`
    );
    const lastCheckins = await query<{
      team_id: string;
      captured_at: Date;
      slot: number;
      participant_name: string;
    }>(
      `SELECT DISTINCT ON (c.team_id) c.team_id, c.captured_at, c.slot, p.display_name AS participant_name
       FROM checkin c JOIN participant p ON p.id = c.participant_id
       ORDER BY c.team_id, c.captured_at DESC`
    );
    const recentPoints = await query<{
      team_id: string;
      lat: number;
      lng: number;
      recorded_at: Date;
    }>(
      `SELECT team_id, lat, lng, recorded_at FROM location_point
       WHERE (accuracy IS NULL OR accuracy <= 100)
         AND recorded_at >= now() - interval '2 hours'
       ORDER BY team_id, recorded_at`
    );
    const dueSlot = Math.floor(
      (now.getTime() - ev.start_time.getTime()) / (ev.checkin_interval_min * 60_000)
    );
    const slotCheckins = new Set<string>();
    if (dueSlot >= 0) {
      const { rows } = await query<{ team_id: string }>(
        'SELECT team_id FROM checkin WHERE slot = $1',
        [dueSlot]
      );
      for (const r of rows) slotCheckins.add(r.team_id);
    }

    const pointByTeam = new Map(lastPoints.rows.map((r) => [r.team_id, r]));
    const checkinByTeam = new Map(lastCheckins.rows.map((r) => [r.team_id, r]));
    const pointsByTeam = new Map<string, typeof recentPoints.rows>();
    for (const p of recentPoints.rows) {
      const list = pointsByTeam.get(p.team_id) ?? [];
      list.push(p);
      pointsByTeam.set(p.team_id, list);
    }

    const teamEntries = teams.rows.map((t) => {
      const lp = pointByTeam.get(t.id) ?? null;
      const lc = checkinByTeam.get(t.id) ?? null;
      const minutesSinceLastPoint = lp
        ? Math.floor((now.getTime() - lp.recorded_at.getTime()) / 60_000)
        : null;
      const silenceCutoff = now.getTime() - ev.silence_alarm_min * 60_000;
      const silent =
        (!lp || lp.recorded_at.getTime() <= silenceCutoff) &&
        (!lc || lc.captured_at.getTime() <= silenceCutoff);
      const dueAt = 
        ev.start_time.getTime() + dueSlot * ev.checkin_interval_min * 60_000 +
        ev.checkin_window_min * 60_000;
      const checkinOverdue =
        dueSlot >= 0 && now.getTime() > dueAt && !slotCheckins.has(t.id);
      const speeding = flagSpeeding(pointsByTeam.get(t.id) ?? [], ev.speed_flag_kmh);
      return {
        id: t.id,
        name: t.name,
        code: t.code,
        status: t.status,
        battery: lp?.battery ?? null,
        minutes_since_last_point: minutesSinceLastPoint,
        last_point: lp
          ? {
              lat: lp.lat,
              lng: lp.lng,
              recorded_at: lp.recorded_at.toISOString(),
              accuracy: lp.accuracy,
            }
          : null,
        last_checkin: lc
          ? {
              captured_at: lc.captured_at.toISOString(),
              slot: lc.slot,
              participant_name: lc.participant_name,
            }
          : null,
        hints: eventRunning
          ? { silent, checkin_overdue: checkinOverdue, speeding }
          : { silent: false, checkin_overdue: false, speeding: false },
      };
    });

    const alerts = await query<{
      id: string;
      type: string;
      lat: number | null;
      lng: number | null;
      created_at: Date;
      team_name: string;
      resolved_at: Date | null;
    }>(
      `SELECT a.id, a.type, a.lat, a.lng, a.created_at, t.name AS team_name, a.resolved_at
       FROM alert a JOIN team t ON t.id = a.team_id
       ORDER BY a.created_at DESC`
    );

    void reply.send({
      server_now: now.toISOString(),
      event: {
        name: ev.name,
        start_lat: ev.start_lat,
        start_lng: ev.start_lng,
        reveal_time: ev.reveal_time === null ? null : ev.reveal_time.toISOString(),
        start_time: ev.start_time.toISOString(),
        end_time: endTime.toISOString(),
        duration_h: ev.duration_h,
        checkin_interval_min: ev.checkin_interval_min,
        checkin_window_min: ev.checkin_window_min,
        silence_alarm_min: ev.silence_alarm_min,
        speed_flag_kmh: ev.speed_flag_kmh,
        orga_phone: ev.orga_phone,
      },
      teams: teamEntries,
      alerts: alerts.rows.map((a) => ({
        id: a.id,
        type: a.type,
        lat: a.lat,
        lng: a.lng,
        created_at: a.created_at.toISOString(),
        team_name: a.team_name,
        resolved: a.resolved_at !== null,
      })),
    });
  });

  app.get('/orga/track', async (request, reply) => {
    const q = z
      .object({ team: uuid, since: z.string().datetime().optional() })
      .safeParse(request.query);
    if (!q.success) {
      void reply.code(400).send({ error: 'Ungültige Eingabe' });
      return;
    }
    const since = q.data.since !== undefined ? new Date(q.data.since) : new Date(Date.now() - 6 * 3600_000);
    const { rows } = await query<{
      id: string;
      lat: number;
      lng: number;
      recorded_at: Date;
      accuracy: number | null;
      battery: number | null;
    }>(
      `SELECT id, lat, lng, recorded_at, accuracy, battery FROM location_point
       WHERE team_id = $1 AND recorded_at >= $2 ORDER BY recorded_at`,
      [q.data.team, since.toISOString()]
    );
    void reply.send(
      rows.map((r) => ({
        id: r.id,
        lat: r.lat,
        lng: r.lng,
        recorded_at: r.recorded_at.toISOString(),
        accuracy: r.accuracy,
        battery: r.battery,
      }))
    );
  });

  app.get('/orga/checkins', async (request, reply) => {
    const q = z.object({ team: uuid }).safeParse(request.query);
    if (!q.success) {
      void reply.code(400).send({ error: 'Ungültige Eingabe' });
      return;
    }
    const { rows } = await query<{
      id: string;
      slot: number;
      media_type: string;
      captured_at: Date;
      participant_name: string;
    }>(
      `SELECT c.id, c.slot, c.media_type, c.captured_at, p.display_name AS participant_name
       FROM checkin c JOIN participant p ON p.id = c.participant_id
       WHERE c.team_id = $1 ORDER BY c.captured_at`,
      [q.data.team]
    );
    void reply.send(
      rows.map((r) => ({
        id: r.id,
        slot: r.slot,
        media_type: r.media_type,
        captured_at: r.captured_at.toISOString(),
        participant_name: r.participant_name,
      }))
    );
  });

  const CONTENT_TYPES: Record<string, string> = {
    '.jpg': 'image/jpeg',
    '.png': 'image/png',
    '.mp4': 'video/mp4',
    '.mov': 'video/quicktime',
  };

  app.get('/orga/media/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    if (!uuid.safeParse(id).success) {
      void reply.code(400).send({ error: 'Ungültige Eingabe' });
      return;
    }
    const { rows } = await query<{ media_path: string }>(
      'SELECT media_path FROM checkin WHERE id = $1',
      [id]
    );
    if (rows.length === 0) {
      void reply.code(404).send({ error: 'Nicht gefunden' });
      return;
    }
    const uploadRoot = path.resolve(config.uploadDir);
    const filePath = path.resolve(uploadRoot, rows[0].media_path);
    if (!filePath.startsWith(uploadRoot + path.sep)) {
      void reply.code(404).send({ error: 'Nicht gefunden' });
      return;
    }
    let size: number;
    try {
      size = (await stat(filePath)).size;
    } catch {
      void reply.code(404).send({ error: 'Nicht gefunden' });
      return;
    }
    const contentType = CONTENT_TYPES[path.extname(filePath).toLowerCase()] ?? 'application/octet-stream';

    const rangeHeader = request.headers.range;
    const match = rangeHeader !== undefined ? /^bytes=(\d*)-(\d*)$/.exec(rangeHeader.trim()) : null;
    if (match !== null && !(match[1] === '' && match[2] === '')) {
      const start = match[1] === '' ? null : parseInt(match[1], 10);
      const end = match[2] === '' ? null : parseInt(match[2], 10);
      const effectiveStart = start ?? Math.max(0, size - (end ?? 0));
      const effectiveEnd = end === null ? size - 1 : Math.min(end, size - 1);
      if (
        Number.isNaN(effectiveStart) ||
        Number.isNaN(effectiveEnd) ||
        effectiveStart > effectiveEnd ||
        effectiveStart >= size
      ) {
        void reply.code(416).send({ error: 'Ungültiger Range' });
        return;
      }
      void reply
        .code(206)
        .header('Content-Type', contentType)
        .header('Accept-Ranges', 'bytes')
        .header('Content-Range', `bytes ${effectiveStart}-${effectiveEnd}/${size}`)
        .header('Content-Length', effectiveEnd - effectiveStart + 1);
      void reply.send(createReadStream(filePath, { start: effectiveStart, end: effectiveEnd }));
      return reply;
    }

    void reply
      .code(200)
      .header('Content-Type', contentType)
      .header('Accept-Ranges', 'bytes')
      .header('Content-Length', size);
    void reply.send(createReadStream(filePath));
    return reply;
  });

  app.post('/orga/alerts/:id/resolve', async (request, reply) => {
    const { id } = request.params as { id: string };
    if (!uuid.safeParse(id).success) {
      void reply.code(400).send({ error: 'Ungültige Eingabe' });
      return;
    }
    await query('UPDATE alert SET resolved_at = now() WHERE id = $1 AND resolved_at IS NULL', [id]);
    void reply.send({ ok: true });
  });

  app.post('/orga/ranking', async (request, reply) => {
    const q = z.object({ final: z.enum(['true', 'false']).optional() }).safeParse(request.query);
    if (!q.success) {
      void reply.code(400).send({ error: 'Ungültige Eingabe' });
      return;
    }
    const isFinal = q.data.final === 'true';
    const evRes = await query<{ start_lat: number | null; start_lng: number | null; start_time: Date; duration_h: number }>(
      'SELECT start_lat, start_lng, start_time, duration_h FROM event WHERE id = 1'
    );
    if (evRes.rows.length === 0) {
      void reply.code(500).send({ error: 'Event nicht konfiguriert' });
      return;
    }
    const ev = evRes.rows[0];
    if (ev.start_lat === null || ev.start_lng === null) {
      void reply.code(400).send({ error: 'Startpunkt nicht gesetzt' });
      return;
    }
    const endTime = new Date(ev.start_time.getTime() + ev.duration_h * 3600_000);
    const cutoff = endTime.getTime() < Date.now() ? endTime : new Date();
    const lastPoints = await query<{ team_id: string; lat: number; lng: number }>(
      `SELECT DISTINCT ON (team_id) team_id, lat, lng FROM location_point
       WHERE recorded_at <= $1 ORDER BY team_id, recorded_at DESC`,
      [cutoff.toISOString()]
    );
    const teams = await query<{ id: string; name: string }>('SELECT id, name FROM team');

    const distanceByTeam = new Map(lastPoints.rows.map((r) => [r.team_id, r]));
    const withPoints = teams.rows
      .filter((t) => distanceByTeam.has(t.id))
      .map((t) => ({
        team_id: t.id,
        team_name: t.name,
        distance_km: haversineKm(ev.start_lat!, ev.start_lng!, distanceByTeam.get(t.id)!.lat, distanceByTeam.get(t.id)!.lng),
      }))
      // Rank 1 = largest distance, ties share the rank (RANK() semantics).
      .sort((a, b) => b.distance_km - a.distance_km || a.team_name.localeCompare(b.team_name));
    const withoutPoints = teams.rows
      .filter((t) => !distanceByTeam.has(t.id))
      .map((t) => ({ team_id: t.id, team_name: t.name, distance_km: null as number | null }))
      .sort((a, b) => a.team_name.localeCompare(b.team_name));

    const computedAt = new Date();
    const entries: { team_id: string; team_name: string; rank: number; distance_km: number | null }[] = [];
    let rank = 0;
    let prevDistance = Number.NaN;
    withPoints.forEach((e, i) => {
      if (e.distance_km !== prevDistance) {
        rank = i + 1;
        prevDistance = e.distance_km;
      }
      entries.push({ ...e, rank });
    });
    for (const e of withoutPoints) {
      entries.push({ ...e, rank: withPoints.length + 1 });
    }

    for (const e of entries) {
      await query(
        `INSERT INTO ranking_snapshot (computed_at, team_id, rank, distance_km, is_final)
         VALUES ($1, $2, $3, $4, $5)`,
        [computedAt.toISOString(), e.team_id, e.rank, e.distance_km, isFinal]
      );
    }
    void reply.send({
      computed_at: computedAt.toISOString(),
      entries,
    });
  });

  app.get('/orga/ranking', async (_request, reply) => {
    const { rows } = await query<{
      computed_at: Date;
      is_final: boolean;
      team_id: string;
      team_name: string;
      rank: number;
      distance_km: number | null;
    }>(
      `SELECT r.computed_at, r.is_final, r.team_id, t.name AS team_name, r.rank, r.distance_km
       FROM ranking_snapshot r JOIN team t ON t.id = r.team_id
       WHERE r.computed_at = (SELECT max(computed_at) FROM ranking_snapshot)
       ORDER BY r.rank, t.name`
    );
    if (rows.length === 0) {
      void reply.code(404).send({ error: 'Noch keine Rangliste' });
      return;
    }
    void reply.send({
      computed_at: rows[0].computed_at.toISOString(),
      is_final: rows[0].is_final,
      entries: rows.map((r) => ({
        team_id: r.team_id,
        team_name: r.team_name,
        rank: r.rank,
        distance_km: r.distance_km,
      })),
    });
  });
}
