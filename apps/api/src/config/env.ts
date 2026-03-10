// Environment config loader and defaults for API runtime.
import 'dotenv/config';

export type DbClient = 'postgres' | 'mysql';
export type TenantMode = 'saas' | 'private';
export type UserRole = 'broker' | 'consumer' | 'admin';

// Ensure required environment variables are present.
function readEnv(name: string, fallback?: string): string {
  const value = process.env[name] ?? fallback;
  if (value === undefined || value === '') {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

// Parse common boolean string values.
function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined) {
    return fallback;
  }
  return ['1', 'true', 'yes', 'on'].includes(value.toLowerCase());
}

const rawDbClient = (process.env.DB_CLIENT ?? 'postgres').toLowerCase();
const dbClient: DbClient = rawDbClient === 'mysql' ? 'mysql' : 'postgres';

const rawTenantMode = (process.env.TENANT_MODE ?? 'saas').toLowerCase();
const tenantMode: TenantMode = rawTenantMode === 'private' ? 'private' : 'saas';

export const env = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  host: process.env.HOST ?? '0.0.0.0',
  port: Number(process.env.PORT ?? 3000),
  dbClient,
  databaseUrl: readEnv(
    'DATABASE_URL',
    dbClient === 'postgres'
      ? 'postgres://postgres:postgres@postgres:5432/wearefamily'
      : 'mysql://root:root@mysql:3306/wearefamily',
  ),
  tenantMode,
  defaultTenantId: process.env.DEFAULT_TENANT_ID ?? 'tenant-demo',
  autoMigrate: parseBoolean(process.env.AUTO_MIGRATE, true),
  authRequired: parseBoolean(process.env.AUTH_REQUIRED, true),
  jwtSecret: readEnv('JWT_SECRET', 'dev-secret-change-me'),
  jwtIssuer: process.env.JWT_ISSUER ?? 'wearefamily-api',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '12h',
  uploadDir: process.env.UPLOAD_DIR ?? './uploads',
};
