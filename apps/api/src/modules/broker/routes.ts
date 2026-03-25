import type { FastifyPluginAsync } from 'fastify';

import { db } from '../../db/knex';
import { IncomeBenchmarkService } from '../benchmarks/service';
import { FamilyRepository } from '../families/repository';
import { PolicyValueAnalysisRepository } from '../value-analysis/repository';

interface PolicyLiteRow {
  id: string;
  family_id: string;
  premium: string | number;
  status: string;
  end_date: string | null;
}

type SortField = 'risk' | 'premiumIncomeRatio' | 'valueScore' | 'renewalDueDays';
type SortOrder = 'asc' | 'desc';

function daysUntil(endDate: string | null): number | null {
  if (!endDate) {
    return null;
  }
  const parsed = new Date(endDate);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return Math.ceil((parsed.getTime() - Date.now()) / 86400000);
}

function computeRiskScore(input: {
  premiumIncomeRatio: number;
  valueScore: number | null;
  expiringSoonCount: number;
  totalPolicies: number;
}): number {
  const premiumPressure = Math.min(100, input.premiumIncomeRatio * 100);
  const valuePressure = input.valueScore === null ? 55 : (100 - input.valueScore);
  const renewalPressure = input.totalPolicies > 0
    ? (input.expiringSoonCount / input.totalPolicies) * 100
    : 0;
  return Math.round(Math.min(100, premiumPressure * 0.4 + valuePressure * 0.35 + renewalPressure * 0.25));
}

function toRiskLevel(score: number): 'low' | 'medium' | 'high' {
  if (score >= 65) {
    return 'high';
  }
  if (score >= 40) {
    return 'medium';
  }
  return 'low';
}

const brokerRoutes: FastifyPluginAsync = async (app) => {
  const familyRepository = new FamilyRepository();
  const benchmarkService = new IncomeBenchmarkService({ logger: app.log });
  const analysisRepository = new PolicyValueAnalysisRepository();

  app.get('/families', async (request, reply) => {
    if (request.userContext.role === 'consumer') {
      return reply.code(403).send({ message: 'Forbidden.' });
    }

    const query = request.query as {
      sortBy?: SortField;
      order?: SortOrder;
      risk?: 'low' | 'medium' | 'high';
    };
    const sortBy: SortField = query.sortBy ?? 'risk';
    const sortOrder: SortOrder = query.order === 'asc' ? 'asc' : 'desc';

    const [families, currentBenchmark] = await Promise.all([
      familyRepository.listFamilies(request.userContext),
      benchmarkService.refreshIfStale(false),
    ]);

    const policyRows = await db<PolicyLiteRow>('policies')
      .where('tenant_id', request.userContext.tenantId)
      .select(['id', 'family_id', 'premium', 'status', 'end_date']);

    const policyIds = policyRows.map((row) => row.id);
    const analysisMap = await analysisRepository.findLatestByPolicies(request.userContext.tenantId, policyIds);
    const benchmarkAnnualIncome = currentBenchmark.snapshot.annualIncome;
    const benchmarkMonthlyIncome = benchmarkAnnualIncome / 12;

    const items = families.map((family) => {
      const familyPolicies = policyRows.filter((row) => row.family_id === family.id);
      const totalPolicies = familyPolicies.length;
      const activePolicies = familyPolicies.filter((row) => row.status === 'active').length;
      const premiumAnnualTotal = familyPolicies.reduce((sum, row) => sum + Number(row.premium ?? 0), 0);
      const premiumMonthly = premiumAnnualTotal / 12;
      const premiumIncomeRatio = benchmarkMonthlyIncome > 0 ? premiumMonthly / benchmarkMonthlyIncome : 0;

      const valueScores = familyPolicies
        .map((row) => analysisMap.get(row.id)?.valueScore)
        .filter((score): score is number => typeof score === 'number' && Number.isFinite(score));
      const valueScore = valueScores.length > 0
        ? Number((valueScores.reduce((sum, score) => sum + score, 0) / valueScores.length).toFixed(2))
        : null;

      const expiryDays = familyPolicies
        .map((row) => daysUntil(row.end_date))
        .filter((value): value is number => value !== null);
      const renewalDueDays = expiryDays.length > 0 ? Math.min(...expiryDays) : null;
      const expiringSoonCount = expiryDays.filter((value) => value >= 0 && value <= 30).length;

      const riskScore = computeRiskScore({
        premiumIncomeRatio,
        valueScore,
        expiringSoonCount,
        totalPolicies,
      });
      const riskLevel = toRiskLevel(riskScore);

      return {
        familyId: family.id,
        familyName: family.name,
        ownerUserId: family.ownerUserId,
        totalPolicies,
        activePolicies,
        expiringSoonCount,
        renewalDueDays,
        premiumAnnualTotal: Number(premiumAnnualTotal.toFixed(2)),
        premiumMonthlyAvg: Number(premiumMonthly.toFixed(2)),
        premiumIncomeRatio: Number(premiumIncomeRatio.toFixed(4)),
        valueScore,
        risk: riskScore,
        riskScore,
        riskLevel,
      };
    });

    const filtered = query.risk
      ? items.filter((item) => item.riskLevel === query.risk)
      : items;

    filtered.sort((left, right) => {
      const l = left[sortBy] ?? 0;
      const r = right[sortBy] ?? 0;
      const leftValue = typeof l === 'number' ? l : Number(l);
      const rightValue = typeof r === 'number' ? r : Number(r);
      return sortOrder === 'asc' ? leftValue - rightValue : rightValue - leftValue;
    });

    return {
      total: filtered.length,
      benchmark: {
        annualIncome: benchmarkAnnualIncome,
        monthlyIncome: Number(benchmarkMonthlyIncome.toFixed(2)),
        source: currentBenchmark.snapshot.source,
        region: currentBenchmark.snapshot.region,
        currency: currentBenchmark.snapshot.currency,
        asOf: currentBenchmark.snapshot.fetchedAt,
        stale: currentBenchmark.stale,
      },
      items: filtered,
    };
  });
};

export default brokerRoutes;
