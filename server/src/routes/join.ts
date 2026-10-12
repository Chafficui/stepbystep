import { randomBytes } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { query } from '../db.js';
import { sha256Hex } from '../auth.js';
import { rateLimit } from '../ratelimit.js';

const joinBody = z.object({
  code: z.string().min(4).max(16),
  display_name: z.string().min(1).max(40),
  device_id: z.string().uuid(),
});

export async function joinRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    '/join',
    {
      preHandler: rateLimit('join'),
    },
    async (request, reply) => {
      const parsed = joinBody.safeParse(request.body);
      if (!parsed.success) {
        void reply.code(400).send({ error: 'Ungültige Eingabe' });
        return;
      }
      const { code, display_name, device_id } = parsed.data;
      const team = await query<{ id: string; name: string }>(
        'SELECT id, name FROM team WHERE code = $1',
        [code]
      );
      if (team.rows.length === 0) {
        void reply.code(404).send({ error: 'Team-Code unbekannt' });
        return;
      }
      const teamRow = team.rows[0];

      // Idempotent re-join: existing device gets a fresh token for the same participant.
      const existing = await query<{ id: string; display_name: string }>(
        'SELECT id, display_name FROM participant WHERE device_id = $1',
        [device_id]
      );
      const token = randomBytes(32).toString('hex');
      if (existing.rows.length > 0) {
        const participant = existing.rows[0];
        await query('UPDATE participant SET token_hash = $1 WHERE id = $2', [
          sha256Hex(token),
          participant.id,
        ]);
        void reply.send({
          token,
          team_id: teamRow.id,
          team_name: teamRow.name,
          display_name: participant.display_name,
        });
        return;
      }

      const count = await query<{ count: string }>(
        'SELECT count(*) AS count FROM participant WHERE team_id = $1',
        [teamRow.id]
      );
      if (parseInt(count.rows[0].count, 10) >= 2) {
        void reply.code(409).send({ error: 'Dieses Team ist bereits voll' });
        return;
      }
      const inserted = await query<{ id: string }>(
        'INSERT INTO participant (team_id, display_name, device_id, token_hash) VALUES ($1, $2, $3, $4) RETURNING id',
        [teamRow.id, display_name, device_id, sha256Hex(token)]
      );
      void inserted;
      void reply.send({
        token,
        team_id: teamRow.id,
        team_name: teamRow.name,
        display_name,
      });
    }
  );
}
