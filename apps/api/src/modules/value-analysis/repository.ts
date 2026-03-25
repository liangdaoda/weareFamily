import { randomUUID } from 'node:crypto';

import { db } from '../../db/knex';
import type { PolicyValueAnalysis, ValueDimension } from './model';

interface PolicyValueAnalysisRow {
  id: string;
  tenant_id: string;
  family_id: string;
  policy_id: string;
  value_score: string | number;
  value_confidence: string | number;
  dimensions: string;
  reasons: string | null;
  recommendations: string | null;
  summary: string | null;
  scoring_version: string;
  created_at: string;
  updated_at: string;
}

function parseStringList(value: string | null): string[] {
  if (!value) {
    return [];
  }

  try {
    const parsed = JSON.parse(value);
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed.map((item) => String(item)).filter((item) => Boolean(item.trim()));
  } catch {
    return [];
  }
}

function parseDimensions(value: string): ValueDimension[] {
  try {
    const parsed = JSON.parse(value);
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed
      .filter((item) => item && typeof item === 'object')
      .map((item) => {
        const obj = item as Record<string, unknown>;
        return {
          key: String(obj.key) as ValueDimension['key'],
          weight: Number(obj.weight ?? 0),
          score: Number(obj.score ?? 0),
          reason: String(obj.reason ?? ''),
        };
      })
      .filter((item) => Number.isFinite(item.weight) && Number.isFinite(item.score));
  } catch {
    return [];
  }
}

function mapRow(row: PolicyValueAnalysisRow): PolicyValueAnalysis {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    familyId: row.family_id,
    policyId: row.policy_id,
    valueScore: Number(row.value_score ?? 0),
    valueConfidence: Number(row.value_confidence ?? 0),
    dimensions: parseDimensions(row.dimensions),
    reasons: parseStringList(row.reasons),
    recommendations: parseStringList(row.recommendations),
    summary: row.summary,
    scoringVersion: row.scoring_version,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export class PolicyValueAnalysisRepository {
  async findLatestByPolicy(tenantId: string, policyId: string): Promise<PolicyValueAnalysis | null> {
    const row = await db<PolicyValueAnalysisRow>('policy_value_analyses')
      .where('tenant_id', tenantId)
      .andWhere('policy_id', policyId)
      .orderBy('updated_at', 'desc')
      .first();
    return row ? mapRow(row) : null;
  }

  async findLatestByPolicies(
    tenantId: string,
    policyIds: string[],
  ): Promise<Map<string, PolicyValueAnalysis>> {
    if (policyIds.length === 0) {
      return new Map();
    }

    const rows = await db<PolicyValueAnalysisRow>('policy_value_analyses')
      .where('tenant_id', tenantId)
      .whereIn('policy_id', policyIds)
      .orderBy('updated_at', 'desc');

    const map = new Map<string, PolicyValueAnalysis>();
    for (const row of rows) {
      if (map.has(row.policy_id)) {
        continue;
      }
      map.set(row.policy_id, mapRow(row));
    }
    return map;
  }

  async upsert(input: {
    tenantId: string;
    familyId: string;
    policyId: string;
    valueScore: number;
    valueConfidence: number;
    dimensions: ValueDimension[];
    reasons: string[];
    recommendations: string[];
    summary: string | null;
    scoringVersion: string;
  }): Promise<PolicyValueAnalysis> {
    const now = new Date().toISOString();
    const existing = await this.findLatestByPolicy(input.tenantId, input.policyId);

    if (existing) {
      await db('policy_value_analyses')
        .where('id', existing.id)
        .update({
          value_score: input.valueScore,
          value_confidence: input.valueConfidence,
          dimensions: JSON.stringify(input.dimensions),
          reasons: JSON.stringify(input.reasons),
          recommendations: JSON.stringify(input.recommendations),
          summary: input.summary,
          scoring_version: input.scoringVersion,
          updated_at: now,
        });

      return {
        ...existing,
        valueScore: input.valueScore,
        valueConfidence: input.valueConfidence,
        dimensions: input.dimensions,
        reasons: input.reasons,
        recommendations: input.recommendations,
        summary: input.summary,
        scoringVersion: input.scoringVersion,
        updatedAt: now,
      };
    }

    const row: PolicyValueAnalysisRow = {
      id: randomUUID(),
      tenant_id: input.tenantId,
      family_id: input.familyId,
      policy_id: input.policyId,
      value_score: input.valueScore,
      value_confidence: input.valueConfidence,
      dimensions: JSON.stringify(input.dimensions),
      reasons: JSON.stringify(input.reasons),
      recommendations: JSON.stringify(input.recommendations),
      summary: input.summary,
      scoring_version: input.scoringVersion,
      created_at: now,
      updated_at: now,
    };

    await db('policy_value_analyses').insert(row);
    return mapRow(row);
  }
}

