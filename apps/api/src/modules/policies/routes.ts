// Policy listing and creation endpoints.
import type { FastifyPluginAsync } from 'fastify';

import { FamilyRepository } from '../families/repository';
import { PolicyRepository } from './repository';
import type { CreatePolicyInput, PolicyStatus } from './model';

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

    const items = await repository.listPolicies(request.userContext, filters);
    return { total: items.length, items };
  });

  app.post('/', async (request, reply) => {
    try {
      const input = assertCreatePolicyBody(request.body);
      const family = await familyRepository.ensureFamilyAccess(request.userContext, input.familyId);
      if (!family) {
        return reply.code(404).send({ message: 'Family not found.' });
      }
      const created = await repository.createPolicy(request.userContext, input);
      return reply.code(201).send(created);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Invalid request body.';
      return reply.code(400).send({ message });
    }
  });
};

export default policyRoutes;
