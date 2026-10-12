import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { query } from '../db.js';
import { requireParticipant } from '../auth.js';

interface EventRow {
  name: string;
  start_lat: number | null;
  start_lng: number | null;
  reveal_time: Date | null;
  start_time: Date;
  duration_h: number;
  checkin_interval_min: number;
  checkin_window_min: number;
  orga_phone: string;
}

function iso(d: Date | null): string | null {
  return d === null ? null : d.toISOString();
}

export async function participantEventRoutes(app: FastifyInstance): Promise<void> {
  app.get('/event', { preHandler: requireParticipant }, async (_request, reply) => {
    const { rows } = await query<EventRow>(
      `SELECT name, start_lat, start_lng, reveal_time, start_time, duration_h,
              checkin_interval_min, checkin_window_min, orga_phone
       FROM event WHERE id = 1`
    );
    if (rows.length === 0) {
      void reply.code(500).send({ error: 'Event nicht konfiguriert' });
      return;
    }
    const e = rows[0];
    const now = new Date();
    const end = new Date(e.start_time.getTime() + e.duration_h * 3600_000);
    const revealed = e.reveal_time !== null && now.getTime() >= e.reveal_time.getTime();
    void reply.send({
      name: e.name,
      start_lat: revealed ? e.start_lat : null,
      start_lng: revealed ? e.start_lng : null,
      reveal_time: iso(e.reveal_time),
      start_time: iso(e.start_time)!,
      end_time: end.toISOString(),
      duration_h: e.duration_h,
      checkin_interval_min: e.checkin_interval_min,
      checkin_window_min: e.checkin_window_min,
      orga_phone: e.orga_phone,
      server_now: now.toISOString(),
    });
  });
}

// zod schema shared with the orga PUT route (also exported for reuse).
export const orgaEventUpdate = z
  .object({
    name: z.string().min(1).max(120).optional(),
    start_lat: z.number().min(-90).max(90).optional(),
    start_lng: z.number().min(-180).max(180).optional(),
    reveal_time: z.string().datetime().optional(),
    start_time: z.string().datetime().optional(),
    duration_h: z.number().int().min(1).max(72).optional(),
    checkin_interval_min: z.number().int().min(10).max(1440).optional(),
    checkin_window_min: z.number().int().min(10).max(1440).optional(),
    silence_alarm_min: z.number().int().min(10).max(1440).optional(),
    speed_flag_kmh: z.number().min(0).max(100).optional(),
    orga_phone: z.string().max(40).optional(),
  })
  .strict();
