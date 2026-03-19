// Data access layer for policy records.
import { randomUUID } from 'node:crypto';

import { db } from '../../db/knex';
import type { UserContext } from '../../types/user-context';
import type { CreatePolicyInput, ListPoliciesInput, Policy } from './model';

interface PolicyRow {
  id: string;
  tenant_id: string;
  family_id: string;
  policy_no: string;
  insurer_name: string;
  product_name: string;
  premium: string | number;
  currency: string;
  status: string;
  start_date: string;
  end_date: string | null;
  ai_risk_score: string | number | null;
  ai_notes: string | null;
  ai_payload: string | null;
  created_by_user_id: string;
  created_at: string;
  updated_at: string;
}

function parseAiPayload(value: string | null): Policy['aiPayload'] {
  if (!value) {
    return null;
  }
  try {
    const parsed = JSON.parse(value);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return null;
    }
    return parsed as Policy['aiPayload'];
  } catch {
    return null;
  }
}

// Map database row (snake_case) to API response (camelCase).
function mapRow(row: PolicyRow): Policy {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    familyId: row.family_id,
    policyNo: row.policy_no,
    insurerName: row.insurer_name,
    productName: row.product_name,
    premium: Number(row.premium),
    currency: row.currency,
    status: row.status as Policy['status'],
    startDate: row.start_date,
    endDate: row.end_date,
    aiRiskScore: row.ai_risk_score === null ? null : Number(row.ai_risk_score),
    aiNotes: row.ai_notes,
    aiPayload: parseAiPayload(row.ai_payload),
    createdByUserId: row.created_by_user_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export class PolicyRepository {
  async listPolicies(ctx: UserContext, filters: ListPoliciesInput): Promise<Policy[]> {
    const query = db<PolicyRow>('policies').where('tenant_id', ctx.tenantId);

    if (ctx.role === 'consumer') {
      query.andWhere('created_by_user_id', ctx.userId);
    }

    if (filters.status) {
      query.andWhere('status', filters.status);
    }

    const rows = await query.orderBy('created_at', 'desc');
    return rows.map(mapRow);
  }

  // Lookup a single policy under the current tenant and role scope.
  async findPolicyById(ctx: UserContext, policyId: string): Promise<Policy | null> {
    const query = db<PolicyRow>('policies')
      .where('tenant_id', ctx.tenantId)
      .andWhere('id', policyId);

    if (ctx.role === 'consumer') {
      query.andWhere('created_by_user_id', ctx.userId);
    }

    const row = await query.first();
    return row ? mapRow(row) : null;
  }

  async createPolicy(ctx: UserContext, input: CreatePolicyInput): Promise<Policy> {
    const now = new Date().toISOString();

    const payload: PolicyRow = {
      id: randomUUID(),
      tenant_id: ctx.tenantId,
      family_id: input.familyId,
      policy_no: input.policyNo,
      insurer_name: input.insurerName,
      product_name: input.productName,
      premium: input.premium,
      currency: input.currency ?? 'CNY',
      status: input.status ?? 'active',
      start_date: input.startDate,
      end_date: input.endDate ?? null,
      ai_risk_score: input.aiRiskScore ?? null,
      ai_notes: input.aiNotes ?? null,
      ai_payload: input.aiPayload ? JSON.stringify(input.aiPayload) : null,
      created_by_user_id: ctx.userId,
      created_at: now,
      updated_at: now,
    };

    await db('policies').insert(payload);
    return mapRow(payload);
  }

  // Query all policies under a specific family for household-level analysis.
  async listPoliciesByFamily(ctx: UserContext, familyId: string): Promise<Policy[]> {
    const rows = await db<PolicyRow>('policies')
      .where('tenant_id', ctx.tenantId)
      .andWhere('family_id', familyId)
      .orderBy('created_at', 'desc');
    return rows.map(mapRow);
  }

  // Delete a policy and detach related documents from this policy id.
  async deletePolicyById(ctx: UserContext, policyId: string): Promise<boolean> {
    return db.transaction(async (trx) => {
      await trx('policy_documents')
        .where('tenant_id', ctx.tenantId)
        .andWhere('policy_id', policyId)
        .update({ policy_id: null });

      const query = trx<PolicyRow>('policies')
        .where('tenant_id', ctx.tenantId)
        .andWhere('id', policyId);

      if (ctx.role === 'consumer') {
        query.andWhere('created_by_user_id', ctx.userId);
      }

      const deleted = await query.del();
      return deleted > 0;
    });
  }

  // Delete one policy under tenant+family scope and detach related documents.
  async deletePolicyByFamily(ctx: UserContext, input: { familyId: string; policyId: string }): Promise<boolean> {
    return db.transaction(async (trx) => {
      await trx('policy_documents')
        .where('tenant_id', ctx.tenantId)
        .andWhere('policy_id', input.policyId)
        .update({ policy_id: null });

      const deleted = await trx<PolicyRow>('policies')
        .where('tenant_id', ctx.tenantId)
        .andWhere('family_id', input.familyId)
        .andWhere('id', input.policyId)
        .del();

      return deleted > 0;
    });
  }
}
