// Policy listing and creation endpoints.
import type { FastifyPluginAsync } from 'fastify';

import { IncomeBenchmarkService } from '../benchmarks/service';
import { FamilyRepository } from '../families/repository';
import { OpsTaskRepository } from '../tasks/repository';
import { PolicyValueAnalysisRepository } from '../value-analysis/repository';
import { PolicyValueAnalysisService } from '../value-analysis/service';
import { buildPolicyAiOutput, resolveInsightLocale } from './insight';
import { PolicyRepository } from './repository';
import type { CreatePolicyInput, Policy, PolicyRenewalStatus, PolicyStatus } from './model';

const allowedStatuses = new Set<PolicyStatus>(['active', 'pending', 'expired', 'cancelled']);
const allowedRenewalStatuses = new Set<PolicyRenewalStatus>([
  'not_due',
  'due_soon',
  'in_progress',
  'completed',
  'expired',
]);

// Basic runtime validation to keep bad payloads out of the database.
function assertCreatePolicyBody(body: unknown): CreatePolicyInput {
  if (!body || typeof body !== 'object') {
    throw new Error('Invalid payload: request body must be an object.');
  }

  const payload = body as Partial<CreatePolicyInput>;
  const requiredFields: Array<keyof CreatePolicyInput> = [
    'familyId',
    'policyNo',
    'insurerName',
    'productName',
    'premium',
    'startDate',
  ];

  for (const field of requiredFields) {
    if (payload[field] === undefined || payload[field] === null || payload[field] === '') {
      throw new Error(`Invalid payload: missing field "${field}".`);
    }
  }

  if (typeof payload.premium !== 'number' || Number.isNaN(payload.premium) || payload.premium < 0) {
    throw new Error('Invalid payload: "premium" must be a non-negative number.');
  }

  if (payload.status && !allowedStatuses.has(payload.status)) {
    throw new Error('Invalid payload: unsupported policy status.');
  }

  return {
    familyId: String(payload.familyId),
    policyNo: String(payload.policyNo),
    insurerName: String(payload.insurerName),
    productName: String(payload.productName),
    premium: payload.premium,
    currency: payload.currency ? String(payload.currency) : undefined,
    status: payload.status,
    startDate: String(payload.startDate),
    endDate: payload.endDate ? String(payload.endDate) : null,
    aiRiskScore: payload.aiRiskScore ?? null,
    aiNotes: payload.aiNotes ? String(payload.aiNotes) : null,
    aiPayload: payload.aiPayload ?? null,
  };
}

// Attach localized AI insight at response time while keeping storage language stable.
function isBrokerOrAdmin(role: string): boolean {
  return role === 'broker' || role === 'admin';
}

async function decoratePolicy(
  policy: Policy,
  locale: ReturnType<typeof resolveInsightLocale>,
  valueRepository: PolicyValueAnalysisRepository,
): Promise<Policy> {
  const ai = buildPolicyAiOutput(
    {
      policyNo: policy.policyNo,
      insurerName: policy.insurerName,
      productName: policy.productName,
      premium: policy.premium,
      currency: policy.currency,
      status: policy.status,
      startDate: policy.startDate,
      endDate: policy.endDate,
      aiNotes: policy.aiNotes,
      signals: policy.aiPayload?.signals ?? null,
      coverageItems: policy.aiPayload?.coverageItems ?? null,
    },
    locale,
  );

  const value = await valueRepository.findLatestByPolicy(policy.tenantId, policy.id);

  return {
    ...policy,
    aiRiskScore: ai.aiRiskScore,
    aiNotes: ai.aiNotes,
    aiInsight: ai.aiInsight,
    valueScore: value?.valueScore ?? null,
    valueConfidence: value?.valueConfidence ?? null,
    valueSummary: value?.summary ?? null,
    valueDimensions: value?.dimensions ?? null,
    valueReasons: value?.reasons ?? null,
    valueRecommendations: value?.recommendations ?? null,
    valueScoringVersion: value?.scoringVersion ?? null,
    valueNeedsReview: value ? value.valueConfidence < 0.65 : true,
  };
}

const policyRoutes: FastifyPluginAsync = async (app) => {
  const repository = new PolicyRepository();
  const familyRepository = new FamilyRepository();
  const valueRepository = new PolicyValueAnalysisRepository();
  const valueService = new PolicyValueAnalysisService();
  const benchmarkService = new IncomeBenchmarkService({ logger: app.log });
  const taskRepository = new OpsTaskRepository();

  app.get('/', async (request) => {
    const query = request.query as { status?: string };
    const status = query.status;
    const filters = {
      status: status && allowedStatuses.has(status as PolicyStatus) ? (status as PolicyStatus) : undefined,
    };

    const locale = resolveInsightLocale(request.headers);
    const rows = await repository.listPolicies(request.userContext, filters);
    const items = await Promise.all(rows.map((item) => decoratePolicy(item, locale, valueRepository)));
    return { total: items.length, items };
  });

  app.post('/', async (request, reply) => {
    try {
      const input = assertCreatePolicyBody(request.body);
      const locale = resolveInsightLocale(request.headers);
      const family = await familyRepository.ensureFamilyAccess(request.userContext, input.familyId);
      if (!family) {
        return reply.code(404).send({ message: 'Family not found.' });
      }

      // Persist Chinese notes by default and localize per-request on output.
      const storageAi = buildPolicyAiOutput(
        {
          policyNo: input.policyNo,
          insurerName: input.insurerName,
          productName: input.productName,
          premium: input.premium,
          currency: input.currency ?? 'CNY',
          status: input.status ?? 'active',
          startDate: input.startDate,
          endDate: input.endDate ?? null,
          aiNotes: input.aiNotes,
          signals: input.aiPayload?.signals ?? null,
          coverageItems: input.aiPayload?.coverageItems ?? null,
        },
        'zh',
      );

      const created = await repository.createPolicy(request.userContext, {
        ...input,
        aiRiskScore: storageAi.aiRiskScore,
        aiNotes: storageAi.aiNotes,
        aiPayload: {
          signals: input.aiPayload?.signals ?? null,
          coverageItems: storageAi.aiInsight.coverageItems,
        },
      });

      const currentBenchmark = await benchmarkService.refreshIfStale(false);
      await valueService.refreshForPolicy({
        ctx: request.userContext,
        policy: created,
        annualIncome: currentBenchmark.snapshot.annualIncome,
        locale,
        triggerUserId: request.userContext.userId,
      });

      if (created.renewalStatus === 'due_soon') {
        await taskRepository.createIfNotOpen({
          tenantId: request.userContext.tenantId,
          familyId: created.familyId,
          policyId: created.id,
          taskType: 'renewal_due',
          priority: 'high',
          title: '保单进入30天续保窗口',
          description: '建议尽快完成续保计划并复核责任变化。',
          createdByUserId: request.userContext.userId,
          dueAt: created.endDate,
        });
      }

      const response = await decoratePolicy(created, locale, valueRepository);
      return reply.code(201).send(response);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Invalid request body.';
      return reply.code(400).send({ message });
    }
  });

  app.get('/:policyId/value-analysis', async (request, reply) => {
    const { policyId } = request.params as { policyId: string };
    const found = await repository.findPolicyById(request.userContext, policyId);
    if (!found) {
      return reply.code(404).send({ message: 'Policy not found.' });
    }

    const locale = resolveInsightLocale(request.headers);
    let analysis = await valueRepository.findLatestByPolicy(request.userContext.tenantId, policyId);
    if (!analysis) {
      const currentBenchmark = await benchmarkService.refreshIfStale(false);
      analysis = await valueService.refreshForPolicy({
        ctx: request.userContext,
        policy: found,
        annualIncome: currentBenchmark.snapshot.annualIncome,
        locale,
        triggerUserId: request.userContext.userId,
      });
    }

    return {
      policyId,
      valueScore: analysis.valueScore,
      valueConfidence: analysis.valueConfidence,
      valueSummary: analysis.summary,
      valueDimensions: analysis.dimensions,
      valueReasons: analysis.reasons,
      valueRecommendations: analysis.recommendations,
      scoringVersion: analysis.scoringVersion,
      updatedAt: analysis.updatedAt,
      needsReview: analysis.valueConfidence < 0.65,
    };
  });

  app.post('/:policyId/value-analysis/refresh', async (request, reply) => {
    if (!isBrokerOrAdmin(request.userContext.role)) {
      return reply.code(403).send({ message: 'Forbidden.' });
    }

    const { policyId } = request.params as { policyId: string };
    const found = await repository.findPolicyById(request.userContext, policyId);
    if (!found) {
      return reply.code(404).send({ message: 'Policy not found.' });
    }

    const locale = resolveInsightLocale(request.headers);
    const currentBenchmark = await benchmarkService.refreshIfStale(false);
    const analysis = await valueService.refreshForPolicy({
      ctx: request.userContext,
      policy: found,
      annualIncome: currentBenchmark.snapshot.annualIncome,
      locale,
      triggerUserId: request.userContext.userId,
    });

    return {
      policyId,
      valueScore: analysis.valueScore,
      valueConfidence: analysis.valueConfidence,
      valueSummary: analysis.summary,
      valueDimensions: analysis.dimensions,
      valueReasons: analysis.reasons,
      valueRecommendations: analysis.recommendations,
      scoringVersion: analysis.scoringVersion,
      updatedAt: analysis.updatedAt,
      needsReview: analysis.valueConfidence < 0.65,
    };
  });

  app.patch('/:policyId/lifecycle', async (request, reply) => {
    if (!isBrokerOrAdmin(request.userContext.role)) {
      return reply.code(403).send({ message: 'Forbidden.' });
    }

    const { policyId } = request.params as { policyId: string };
    const body = request.body as {
      renewalStatus?: PolicyRenewalStatus;
      assigneeUserId?: string | null;
      lifecycleNote?: string | null;
    } | null;

    if (!body?.renewalStatus || !allowedRenewalStatuses.has(body.renewalStatus)) {
      return reply.code(400).send({ message: 'Invalid renewal status.' });
    }

    const found = await repository.findPolicyById(request.userContext, policyId);
    if (!found) {
      return reply.code(404).send({ message: 'Policy not found.' });
    }

    const updated = await repository.updateLifecycle(request.userContext, policyId, {
      renewalStatus: body.renewalStatus,
      assigneeUserId: body.assigneeUserId ?? null,
      lifecycleNote: body.lifecycleNote ?? null,
    });
    if (!updated) {
      return reply.code(404).send({ message: 'Policy not found.' });
    }

    if (body.renewalStatus === 'due_soon' || body.renewalStatus === 'in_progress') {
      await taskRepository.createIfNotOpen({
        tenantId: request.userContext.tenantId,
        familyId: updated.familyId,
        policyId: updated.id,
        taskType: 'renewal_due',
        priority: body.renewalStatus === 'due_soon' ? 'high' : 'medium',
        title: body.renewalStatus === 'due_soon' ? '保单进入30天续保窗口' : '保单续保处理中',
        description: body.lifecycleNote ?? '请跟进续保进度并更新状态。',
        assignedUserId: body.assigneeUserId ?? null,
        createdByUserId: request.userContext.userId,
        dueAt: updated.endDate,
      });
    }

    const locale = resolveInsightLocale(request.headers);
    const response = await decoratePolicy(updated, locale, valueRepository);
    return response;
  });

  app.delete('/:policyId', async (request, reply) => {
    const { policyId } = request.params as { policyId: string };
    const found = await repository.findPolicyById(request.userContext, policyId);
    if (!found) {
      return reply.code(404).send({ message: 'Policy not found.' });
    }

    const deleted = await repository.deletePolicyById(request.userContext, policyId);
    if (!deleted) {
      return reply.code(404).send({ message: 'Policy not found.' });
    }

    return reply.code(204).send();
  });
};

export default policyRoutes;
