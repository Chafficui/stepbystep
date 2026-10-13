import type { FastifyInstance, FastifyReply } from 'fastify';
import { readFile, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { z } from 'zod';
import { query } from '../db.js';
import { requireParticipant, getParticipant } from '../auth.js';
import { config } from '../config.js';
import { sniffExt } from './features.js';

const photoFieldsSchema = z.object({
  id: z.string().uuid(),
  captured_at: z.string().datetime(),
});

const sinceSchema = z.object({ since: z.string().datetime().optional() });

const PHOTO_TYPES: Record<string, string> = {
  '.jpg': 'image/jpeg',
  '.png': 'image/png',
};

const MAX_TRACK_POINTS = 5000;

/** Resolve a stored file name inside the upload dir; null if it would escape it. */
function resolveInUploadDir(name: string): string | null {
  const uploadRoot = path.resolve(config.uploadDir);
  const filePath = path.resolve(uploadRoot, name);
  return filePath.startsWith(uploadRoot + path.sep) ? filePath : null;
}

/** Best-effort removal of a stored photo file (only inside the upload dir). */
export async function deletePhotoFile(name: string | null): Promise<void> {
  if (name === null) return;
  const filePath = resolveInUploadDir(name);
  if (filePath === null) return;
  try {
    await unlink(filePath);
  } catch {
    // already gone or not removable: ignore
  }
}

/** Stream a team's photo (shared by the participant and the orga route). */
export async function sendTeamPhoto(teamId: string, reply: FastifyReply): Promise<void> {
  const { rows } = await query<{ photo_path: string | null }>(
    'SELECT photo_path FROM team WHERE id = $1',
    [teamId]
  );
  const photoPath = rows[0]?.photo_path ?? null;
  const filePath = photoPath === null ? null : resolveInUploadDir(photoPath);
  if (filePath === null) {
    void reply.code(404).send({ error: 'Nicht gefunden' });
    return;
  }
  // Photos are small (one image); read into memory instead of streaming.
  let data: Buffer;
  try {
    data = await readFile(filePath);
  } catch {
    void reply.code(404).send({ error: 'Nicht gefunden' });
    return;
  }
  const contentType = PHOTO_TYPES[path.extname(filePath).toLowerCase()] ?? 'application/octet-stream';
  void reply
    .code(200)
    .header('Content-Type', contentType)
    .header('Cache-Control', 'private, no-cache');
  void reply.send(data);
}

export async function teamPhotoRoutes(app: FastifyInstance): Promise<void> {
  // ---- POST /api/team-photo (multipart) ----
  app.post('/team-photo', { preHandler: requireParticipant }, async (request, reply) => {
    if (!request.isMultipart()) {
      void reply.code(400).send({ error: 'Ungültige Eingabe' });
      return;
    }
    const fields: Record<string, string> = {};
    let file: Buffer | null = null;
    for await (const part of request.parts()) {
      if (part.type === 'file') {
        file = await part.toBuffer();
      } else {
        fields[part.fieldname] = String(part.value);
      }
    }
    const parsed = photoFieldsSchema.safeParse(fields);
    if (!parsed.success || file === null || file.length === 0) {
      void reply.code(400).send({ error: 'Ungültige Eingabe' });
      return;
    }
    const ext = sniffExt(file);
    if (ext !== 'jpg' && ext !== 'png') {
      void reply.code(415).send({ error: 'Dateityp nicht erlaubt' });
      return;
    }
    const participant = getParticipant(request);
    const teamId = participant.team_id;
    // The client-provided file name is never used for storage.
    const photoPath = `team-${teamId}-${parsed.data.id}.${ext}`;

    const current = await query<{ photo_path: string | null; photo_updated_at: Date | null }>(
      'SELECT photo_path, photo_updated_at FROM team WHERE id = $1',
      [teamId]
    );
    if (current.rows.length === 0) {
      void reply.code(404).send({ error: 'Team nicht gefunden' });
      return;
    }
    const prev = current.rows[0];
    if (prev.photo_path === photoPath && prev.photo_updated_at !== null) {
      // Idempotent retry of the same upload.
      void reply.send({ accepted: true, photo_updated_at: prev.photo_updated_at.toISOString() });
      return;
    }

    await writeFile(path.join(config.uploadDir, photoPath), file);
    const updated = await query<{ photo_updated_at: Date }>(
      'UPDATE team SET photo_path = $1, photo_updated_at = now() WHERE id = $2 RETURNING photo_updated_at',
      [photoPath, teamId]
    );
    if (prev.photo_path !== null && prev.photo_path !== photoPath) {
      await deletePhotoFile(prev.photo_path);
    }
    void reply.send({ accepted: true, photo_updated_at: updated.rows[0].photo_updated_at.toISOString() });
  });

  // ---- GET /api/team-photo ----
  app.get('/team-photo', { preHandler: requireParticipant }, async (request, reply) => {
    await sendTeamPhoto(getParticipant(request).team_id, reply);
  });

  // ---- GET /api/my-track ----
  app.get('/my-track', { preHandler: requireParticipant }, async (request, reply) => {
    const q = sinceSchema.safeParse(request.query);
    if (!q.success) {
      void reply.code(400).send({ error: 'Ungültige Eingabe' });
      return;
    }
    const teamId = getParticipant(request).team_id;
    const since = q.data.since ?? null;
    // Newest N rows first (so the cap keeps the LATEST points), re-ordered ascending.
    const { rows } = await query<{
      lat: number;
      lng: number;
      recorded_at: Date;
      participant_id: string;
    }>(
      `SELECT lat, lng, recorded_at, participant_id FROM (
         SELECT lat, lng, recorded_at, participant_id FROM location_point
         WHERE team_id = $1 AND ($2::timestamptz IS NULL OR recorded_at > $2::timestamptz)
         ORDER BY recorded_at DESC
         LIMIT ${MAX_TRACK_POINTS}
       ) t ORDER BY recorded_at ASC`,
      [teamId, since]
    );
    void reply.send({
      points: rows.map((r) => ({
        lat: r.lat,
        lng: r.lng,
        recorded_at: r.recorded_at.toISOString(),
        participant_id: r.participant_id,
      })),
    });
  });
}
