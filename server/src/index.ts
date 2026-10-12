import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { existsSync, mkdirSync } from 'node:fs';
import Fastify from 'fastify';
import fastifyStatic from '@fastify/static';
import fastifyMultipart from '@fastify/multipart';
import { config } from './config.js';
import { migrate } from './migrate.js';
import { joinRoutes } from './routes/join.js';
import { meRoutes } from './routes/me.js';
import { participantEventRoutes } from './routes/event.js';
import { orgaRoutes } from './routes/orga.js';
import { participantFeatureRoutes } from './routes/features.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function resolveDashboardDir(): string {
  return path.isAbsolute(config.dashboardDir)
    ? config.dashboardDir
    : path.resolve(process.cwd(), config.dashboardDir);
}

function findMigrationsDir(): string {
  const candidates = [
    path.resolve(process.cwd(), 'server', 'migrations'),
    path.resolve(process.cwd(), 'migrations'),
  ];
  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }
  return candidates[candidates.length - 1];
}

const SECURITY_HEADERS: Record<string, string> = {
  'Content-Security-Policy':
    "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; img-src 'self' data: blob: https://cdn.jsdelivr.net https://*.tile.openstreetmap.org https://tile.openstreetmap.org; media-src 'self' blob:; connect-src 'self' https://cdn.jsdelivr.net",
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
};

export async function buildApp() {
  const app = Fastify({
    trustProxy: true,
    logger: {
      redact: ['req.headers.authorization'],
    },
    bodyLimit: 1 * 1024 * 1024,
  });

  // Security headers on every response.
  app.addHook('onSend', async (_request, reply) => {
    for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
      void reply.header(name, value);
    }
  });

  // Uniform JSON error shape: {"error": "<message>"}
  app.setErrorHandler((err, _request, reply) => {
    const error = err as { statusCode?: number; message: string };
    const message =
      error.statusCode !== undefined && error.statusCode >= 400
        ? error.message
        : 'Interner Serverfehler';
    void reply.code(error.statusCode ?? 500).send({ error: message });
  });
  app.setNotFoundHandler((_request, reply) => {
    void reply.code(404).send({ error: 'Nicht gefunden' });
  });

  await app.register(fastifyMultipart, {
    limits: { fileSize: 20 * 1024 * 1024 },
  });

  // Upload directory for check-in media (created if missing).
  try {
    mkdirSync(config.uploadDir, { recursive: true });
  } catch (err) {
    console.warn(`Could not create upload dir ${config.uploadDir}: ${String(err)}`);
  }

  const dashboardDir = resolveDashboardDir();
  if (existsSync(dashboardDir)) {
    await app.register(fastifyStatic, { root: dashboardDir });
  }

  app.get('/healthz', async (_request, reply) => {
    void reply.send({ status: 'ok' });
  });

  await app.register(joinRoutes, { prefix: '/api' });
  await app.register(meRoutes, { prefix: '/api' });
  await app.register(participantEventRoutes, { prefix: '/api' });
  await app.register(orgaRoutes, { prefix: '/api' });
  await app.register(participantFeatureRoutes, { prefix: '/api' });

  return app;
}

const isDirectRun =
  process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isDirectRun) {
  await migrate(config.databaseUrl, findMigrationsDir());
  const app = await buildApp();
  await app.listen({ port: config.port, host: '0.0.0.0' });
}
