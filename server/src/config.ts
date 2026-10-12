// Server configuration from environment variables. All secrets come from env.
function requireEnv(name: string, minLen?: number): string {
  const value = process.env[name];
  if (value === undefined || value.length === 0) {
    console.error(`Missing required environment variable: ${name}`);
    process.exit(1);
  }
  if (minLen !== undefined && Buffer.byteLength(value, 'utf8') < minLen) {
    console.error(`Environment variable ${name} must be at least ${minLen} bytes`);
    process.exit(1);
  }
  return value;
}

function optionalEnv(name: string, fallback: string): string {
  const value = process.env[name];
  return value !== undefined && value.length > 0 ? value : fallback;
}

export const config = {
  port: parseInt(process.env.PORT ?? '8080', 10),
  databaseUrl: optionalEnv('DATABASE_URL', 'postgres://postgres:postgres@localhost:5432/postgres'),
  orgaPassword: requireEnv('ORGA_PASSWORD'),
  orgaSessionSecret: requireEnv('ORGA_SESSION_SECRET', 32),
  uploadDir: optionalEnv('UPLOAD_DIR', '/data/uploads'),
  dashboardDir: optionalEnv('DASHBOARD_DIR', '../dashboard'),
};
