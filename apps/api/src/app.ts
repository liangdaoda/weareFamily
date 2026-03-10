// Fastify application factory with core plugins and routes.
import cors from '@fastify/cors';
import multipart from '@fastify/multipart';
import Fastify, { type FastifyInstance } from 'fastify';

import authRoutes from './modules/auth/routes';
import dashboardRoutes from './modules/dashboard/routes';
import familyRoutes from './modules/families/routes';
import healthRoutes from './modules/health/routes';
import policyRoutes from './modules/policies/routes';
import authContextPlugin from './plugins/auth-context';
import { env } from './config/env';

export function buildApp(): FastifyInstance {
  const app = Fastify({
    logger: env.nodeEnv === 'development',
  });

  app.register(cors, {
    origin: true,
  });
  app.register(multipart, {
    limits: {
      fileSize: 10 * 1024 * 1024,
    },
  });
  app.register(authContextPlugin);

  app.register(healthRoutes);
  app.register(authRoutes, { prefix: '/api/v1/auth' });
  app.register(dashboardRoutes, { prefix: '/api/v1/dashboard' });
  app.register(familyRoutes, { prefix: '/api/v1/families' });
  app.register(policyRoutes, { prefix: '/api/v1/policies' });

  app.setErrorHandler((error, request, reply) => {
    // Normalize unknown error into safe response payload.
    const statusCode = typeof (error as { statusCode?: number }).statusCode === 'number'
      ? (error as { statusCode?: number }).statusCode!
      : 500;
    const message = error instanceof Error ? error.message : 'Internal server error';

    request.log.error({ err: error as Error }, 'Unhandled error');
    reply.code(statusCode).send({ message });
  });

  return app;
}
