// API bootstrap: wait for DB, run migrations, then start HTTP server.
import type { FastifyBaseLogger } from 'fastify';

import { buildApp } from './app';
import { env } from './config/env';
import { db, pingDatabase } from './db/knex';
import { runMigrations } from './db/migrate';
import { IncomeBenchmarkService, startIncomeBenchmarkScheduler } from './modules/benchmarks/service';

const maxDbAttempts = 10;
const dbRetryDelayMs = 2000;

// Simple async sleep helper for retry logic.
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

// Retry DB connection to allow container startup ordering.
async function waitForDatabase(logger: FastifyBaseLogger): Promise<void> {
  for (let attempt = 1; attempt <= maxDbAttempts; attempt += 1) {
    try {
      await pingDatabase();
      logger.info({ attempt }, 'Database connection established.');
      return;
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      logger.warn({ attempt, err: message }, 'Database not ready. Retrying...');

      if (attempt === maxDbAttempts) {
        throw error;
      }

      await sleep(dbRetryDelayMs);
    }
  }
}

// Start the Fastify server and attach shutdown hooks.
async function startServer(): Promise<void> {
  const app = buildApp();

  await waitForDatabase(app.log);

  if (env.autoMigrate) {
    app.log.info('Running database migrations.');
    await runMigrations();
  }

  const benchmarkService = new IncomeBenchmarkService({ logger: app.log });
  await benchmarkService.refreshIfStale(false);
  const benchmarkTimer = startIncomeBenchmarkScheduler(benchmarkService, {
    onError: (error) => {
      app.log.warn({ err: error as Error }, 'Income benchmark scheduler run failed.');
    },
  });

  const address = await app.listen({ host: env.host, port: env.port });
  app.log.info({ address }, 'API server started.');

  let shuttingDown = false;
  const shutdown = async (signal: NodeJS.Signals): Promise<void> => {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;
    app.log.info({ signal }, 'Shutting down API server.');
    if (benchmarkTimer) {
      clearInterval(benchmarkTimer);
    }
    await app.close();
    await db.destroy();
    process.exit(0);
  };

  process.on('SIGINT', () => {
    void shutdown('SIGINT');
  });
  process.on('SIGTERM', () => {
    void shutdown('SIGTERM');
  });
}

startServer().catch(async (error) => {
  // eslint-disable-next-line no-console
  console.error('Failed to start API server:', error);
  await db.destroy();
  process.exit(1);
});
