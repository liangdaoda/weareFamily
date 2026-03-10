// Knex database connection and simple health ping.
import knex from 'knex';

import { env } from '../config/env';

export const db = knex({
  client: env.dbClient === 'postgres' ? 'pg' : 'mysql2',
  connection: env.databaseUrl,
  pool: {
    min: 2,
    max: 10,
  },
});

// Lightweight connectivity check.
export async function pingDatabase(): Promise<void> {
  await db.raw('select 1');
}
