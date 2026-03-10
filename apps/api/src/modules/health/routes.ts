// Health check route for container readiness.
import type { FastifyPluginAsync } from 'fastify';

const healthRoutes: FastifyPluginAsync = async (app) => {
  app.get('/health', async () => {
    return {
      status: 'ok',
      service: 'wearefamily-api',
      now: new Date().toISOString(),
    };
  });
};

export default healthRoutes;
