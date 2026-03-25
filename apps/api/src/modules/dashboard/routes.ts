// Dashboard summary endpoints for broker/consumer roles.
import type { FastifyPluginAsync } from 'fastify';

import { db } from '../../db/knex';
import { IncomeBenchmarkService } from '../benchmarks/service';

interface PolicyRow {
  id: string;
  premium: string | number;
  status: string;
  end_date: string | null;
}

// Calculate day span for expiry checks.
function daysBetween(start: Date, end: Date): number {
  const ms = end.getTime() - start.getTime();
  return Math.ceil(ms / (1000 * 60 * 60 * 24));
}

const dashboardRoutes: FastifyPluginAsync = async (app) => {
  const benchmarkService = new IncomeBenchmarkService({ logger: app.log });

  app.get('/summary', async (request) => {
    const ctx = request.userContext;

    const query = db<PolicyRow>('policies').where('tenant_id', ctx.tenantId);

    if (ctx.role === 'consumer') {
      query.andWhere('created_by_user_id', ctx.userId);
    }

    const rows = await query.select(['id', 'premium', 'status', 'end_date']);
    const now = new Date();

    const activePolicies = rows.filter((row) => row.status === 'active').length;
    const expiringSoon = rows.filter((row) => {
      if (!row.end_date) {
        return false;
      }
      const endDate = new Date(row.end_date);
      const diff = daysBetween(now, endDate);
      return diff >= 0 && diff <= 30;
    }).length;
    const premiumTotal = rows.reduce((sum, row) => sum + Number(row.premium ?? 0), 0);
    const currentBenchmark = await benchmarkService.refreshIfStale(false);
    const benchmarkAnnualIncome = currentBenchmark.snapshot.annualIncome;
    const benchmarkMonthlyIncome = benchmarkAnnualIncome / 12;
    const monthlyPremium = premiumTotal / 12;
    const premiumIncomeRatio = benchmarkMonthlyIncome > 0
      ? Number((monthlyPremium / benchmarkMonthlyIncome).toFixed(4))
      : 0;

    return {
      tenantId: ctx.tenantId,
      role: ctx.role,
      tenantMode: ctx.tenantMode,
      benchmark: {
        annualIncome: benchmarkAnnualIncome,
        monthlyIncome: Number(benchmarkMonthlyIncome.toFixed(2)),
        currency: currentBenchmark.snapshot.currency,
        source: currentBenchmark.snapshot.source,
        asOf: currentBenchmark.snapshot.fetchedAt,
        stale: currentBenchmark.stale,
      },
      metrics: {
        totalPolicies: rows.length,
        activePolicies,
        expiringSoon,
        premiumTotal,
        monthlyPremium: Number(monthlyPremium.toFixed(2)),
        premiumIncomeRatio,
      },
    };
  });
};

export default dashboardRoutes;
