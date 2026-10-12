import type { FastifyInstance } from 'fastify';
import { writeFile } from 'node:fs/promises';
import path from 'node:path';
import { z } from 'zod';
import { query } from '../db.js';
import { requireParticipant, getParticipant } from '../auth.js';
import { config } from '../config.js';

// ---- zod schemas (team_id is NEVER accepted from the body; it always comes
// from the authenticated participant) ----

const pointSchema = z.object({
  id: z.string().uuid(),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  accuracy: z.number().min(0).max(100_000).optional(),
  speed: z.number().min(0).max(300).optional(),
  battery: z.number().min(0).max(100).optional(),
  recorded_at: z.string().datetime(),
});

const batchSchema = z.object({ points: z.array(pointSchema).max(200) });

const checkinFieldsSchema = z.object({
  id: z.string().uuid(),
  captured_at: z.string().datetime(),
  media_type: z.enum(['photo', 'video']),
});

const alertSchema = z.object({
  id: z.string().uuid(),
  type: z.enum(['sos', 'abort']),
  lat: z.number().min(-90).max(90).optional(),
  lng: z.number().min(-180).max(180).optional(),
  created_at: z.string().datetime(),
  note: z.string().max(2000).optional(),
});

// ---- magic byte sniffing (client MIME/extension claims are not trusted) ----

const JPEG_MAGIC = Buffer.from([0xff, 0xd8, 0xff]);
const PNG_MAGIC = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

type MediaExt = 'jpg' | 'png' | 'mp4' | 'mov';

function sniffExt(buf: Buffer): MediaExt | null {
  if (buf.length < 12) return null;
  if (buf.subarray(0, 3).equals(JPEG_MAGIC)) return 'jpg';
  if (buf.subarray(0, 8).equals(PNG_MAGIC)) return 'png';
  if (buf.subarray(4, 8).toString('latin1') === 'ftyp') {
    // Major brand at bytes 8..12: qt -> mov, otherwise mp4.
    return buf.subarray(8, 12).toString('latin1') === 'qt  ' ? 'mov' : 'mp4';
  }
  return null;
}

export async function participantFeatureRoutes(app: FastifyInstance): Promise<void> {
  // ---- POST /api/points/batch ----
  app.post(
    '/points/batch',
    { preHandler: requireParticipant },
    async (request, reply) => {
      const parsed = batchSchema.safeParse(request.body);
      if (!parsed.success) {
        void reply.code(400).send({ error: 'Ungültige Eingabe' });
        return;
      }
      const participant = getParticipant(request);
      const now = Date.now();
      // Skip points dated more than 5 minutes in the future.
      const points = parsed.data.points.filter(
        (p) => Date.parse(p.recorded_at) <= now + 5 * 60_000
      );
      for (const p of points) {
        await query(
          `INSERT INTO location_point (id, team_id, participant_id, lat, lng, accuracy, speed, battery, recorded_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
           ON CONFLICT (id) DO NOTHING`,
          [p.id, participant.team_id, participant.id, p.lat, p.lng, p.accuracy ?? null, p.speed ?? null, p.battery ?? null, p.recorded_at]
        );
      }
      // accepted = ids that now exist in the DB for THIS team (covers both
      // freshly inserted and pre-existing own points; ids owned by another
      // team are never reported).
      const ids = points.map((p) => p.id);
      let accepted: string[] = [];
      if (ids.length > 0) {
        const { rows } = await query<{ id: string }>(
          'SELECT id FROM location_point WHERE team_id = $1 AND id = ANY($2::uuid[])',
          [participant.team_id, ids]
        );
        const present = new Set(rows.map((r) => r.id));
        accepted = ids.filter((id) => present.has(id));
      }
      void reply.send({ accepted });
    }
  );

  // ---- POST /api/checkins (multipart) ----
  app.post(
    '/checkins',
    { preHandler: requireParticipant },
    async (request, reply) => {
      if (!request.isMultipart()) {
        void reply.code(400).send({ error: 'Ungültige Eingabe' });
        return;
      }
      const fields: Record<string, string> = {};
      let file: Buffer | null = null;
      const parts = request.parts();
      for await (const part of parts) {
        if (part.type === 'file') {
          file = await part.toBuffer();
        } else {
          fields[part.fieldname] = String(part.value);
        }
      }
      const parsed = checkinFieldsSchema.safeParse(fields);
      if (!parsed.success || file === null || file.length === 0) {
        void reply.code(400).send({ error: 'Ungültige Eingabe' });
        return;
      }
      const participant = getParticipant(request);
      const { id, captured_at, media_type } = parsed.data;

      // Idempotency / cross-team guard.
      const existing = await query<{ team_id: string; slot: number }>(
        'SELECT team_id, slot FROM checkin WHERE id = $1',
        [id]
      );
      if (existing.rows.length > 0) {
        if (existing.rows[0].team_id !== participant.team_id) {
          void reply.code(403).send({ error: 'Unerlaubt' });
          return;
        }
        void reply.send({ accepted: true, slot: existing.rows[0].slot });
        return;
      }

      const ext = sniffExt(file);
      if (ext === null) {
        void reply.code(415).send({ error: 'Dateityp nicht erlaubt' });
        return;
      }

      const ev = await query<{ start_time: Date; checkin_interval_min: number }>(
        'SELECT start_time, checkin_interval_min FROM event WHERE id = 1'
      );
      if (ev.rows.length === 0) {
        void reply.code(500).send({ error: 'Event nicht konfiguriert' });
        return;
      }
      const slot = Math.floor(
        (Date.parse(captured_at) - ev.rows[0].start_time.getTime()) /
          (ev.rows[0].checkin_interval_min * 60_000)
      );

      // The client-provided file name is never used for storage.
      const mediaPath = `${id}.${ext}`;
      await writeFile(path.join(config.uploadDir, mediaPath), file);

      const inserted = await query(
        `INSERT INTO checkin (id, team_id, participant_id, slot, media_path, media_type, captured_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (id) DO NOTHING`,
        [id, participant.team_id, participant.id, slot, mediaPath, media_type, captured_at]
      );
      if (inserted.rowCount === 0) {
        // Lost a race: the row now exists (same team, same id) — report its slot.
        const again = await query<{ slot: number }>('SELECT slot FROM checkin WHERE id = $1', [id]);
        void reply.send({ accepted: true, slot: again.rows[0]?.slot ?? slot });
        return;
      }
      void reply.send({ accepted: true, slot });
    }
  );

  // ---- POST /api/alerts ----
  app.post('/alerts', { preHandler: requireParticipant }, async (request, reply) => {
    const parsed = alertSchema.safeParse(request.body);
    if (!parsed.success) {
      void reply.code(400).send({ error: 'Ungültige Eingabe' });
      return;
    }
    const participant = getParticipant(request);
    const { id, type, lat, lng, created_at, note } = parsed.data;

    const existing = await query<{ team_id: string }>(
      'SELECT team_id FROM alert WHERE id = $1',
      [id]
    );
    if (existing.rows.length > 0) {
      if (existing.rows[0].team_id !== participant.team_id) {
        void reply.code(403).send({ error: 'Unerlaubt' });
        return;
      }
      void reply.send({ accepted: true });
      return;
    }

    await query(
      `INSERT INTO alert (id, team_id, type, lat, lng, created_at, note)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (id) DO NOTHING`,
      [id, participant.team_id, type, lat ?? null, lng ?? null, created_at, note ?? null]
    );
    if (type === 'abort') {
      await query("UPDATE team SET status = 'aborted', status_changed_at = now() WHERE id = $1", [
        participant.team_id,
      ]);
    }
    void reply.send({ accepted: true });
  });

  // ---- GET /api/my-rank ----
  app.get('/my-rank', { preHandler: requireParticipant }, async (request, reply) => {
    const participant = getParticipant(request);
    const { rows } = await query<{ rank: number | null; team_count: number | null; computed_at: Date | null }>(
      `SELECT r.rank AS rank,
              (SELECT count(*)::int FROM ranking_snapshot WHERE computed_at = r.computed_at) AS team_count,
              r.computed_at AS computed_at
       FROM ranking_snapshot r
       WHERE r.computed_at = (SELECT max(computed_at) FROM ranking_snapshot)
         AND r.team_id = $1`,
      [participant.team_id]
    );
    if (rows.length === 0) {
      void reply.send({ rank: null, team_count: null, computed_at: null });
      return;
    }
    void reply.send({
      rank: rows[0].rank,
      team_count: rows[0].team_count,
      computed_at: rows[0].computed_at!.toISOString(),
      // distance_km is deliberately NOT included: participants must not see kilometres.
    });
  });
}

export { sniffExt };