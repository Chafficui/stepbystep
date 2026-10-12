import type { FastifyInstance } from 'fastify';
import { query } from '../db.js';
import { requireParticipant, getParticipant } from '../auth.js';

export async function meRoutes(app: FastifyInstance): Promise<void> {
  app.get('/me', { preHandler: requireParticipant }, async (request, reply) => {
    const participant = getParticipant(request);
    const { rows } = await query<{ id: string; name: string; status: string }>(
      'SELECT id, name, status FROM team WHERE id = $1',
      [participant.team_id]
    );
    if (rows.length === 0) {
      void reply.code(404).send({ error: 'Team nicht gefunden' });
      return;
    }
    void reply.send({
      team_id: rows[0].id,
      team_name: rows[0].name,
      team_status: rows[0].status,
      display_name: participant.display_name,
    });
  });
}
