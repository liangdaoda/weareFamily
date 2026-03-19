// Policy listing and creation endpoints.
import type { FastifyPluginAsync } from 'fastify';

import { FamilyRepository } from '../families/repository';
import { buildPolicyAiOutput, resolveInsightLocale } from './insight';
import { PolicyRepository } from './repository';
import type { CreatePolicyInput, Policy, PolicyStatus } from './model';

const allowedStatuses = new Set<PolicyStatus>(['active', 'pending', 'expired', 'cancelled']);

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
function decoratePolicy(policy: Policy, locale: ReturnType<typeof resolveInsightLocale>): Policy {
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

  return {
    ...policy,
    aiRiskScore: ai.aiRiskScore,
    aiNotes: ai.aiNotes,
    aiInsight: ai.aiInsight,
  };
}

const policyRoutes: FastifyPluginAsync = async (app) => {
  const repository = new PolicyRepository();
  const familyRepository = new FamilyRepository();

  app.get('/', async (request) => {
    const query = request.query as { status?: string };
    const status = query.status;
    const filters = {
      status: status && allowedStatuses.has(status as PolicyStatus) ? (status as PolicyStatus) : undefined,
    };

    const locale = resolveInsightLocale(request.headers);
    const rows = await repository.listPolicies(request.userContext, filters);
    const items = rows.map((item) => decoratePolicy(item, locale));
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
      return reply.code(201).send(decoratePolicy(created, locale));
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Invalid request body.';
      return reply.code(400).send({ message });
    }
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
