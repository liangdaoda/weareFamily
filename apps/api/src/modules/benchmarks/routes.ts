import type { FastifyPluginAsync } from 'fastify';

import { IncomeBenchmarkService } from './service';

const benchmarkRoutes: FastifyPluginAsync = async (app) => {
  const service = new IncomeBenchmarkService({ logger: app.log });

  app.get('/income/current', async () => {
    const current = await service.refreshIfStale(false);
    return {
      source: current.snapshot.source,
      region: current.snapshot.region,
      currency: current.snapshot.currency,
      period: current.snapshot.period,
      annualIncome: current.snapshot.annualIncome,
      monthlyIncome: Number((current.snapshot.annualIncome / 12).toFixed(2)),
      publishedAt: current.snapshot.publishedAt,
      effectiveDate: current.snapshot.effectiveDate,
      fetchedAt: current.snapshot.fetchedAt,
      stale: current.stale,
      sourceMeta: current.sourceMeta,
    };
  });
};

export default benchmarkRoutes;
