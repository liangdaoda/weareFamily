import { randomUUID } from 'node:crypto';

import { db } from '../../db/knex';
import type { IncomeBenchmarkSnapshot } from './model';

interface IncomeBenchmarkSnapshotRow {
  id: string;
  source: string;
  region: string;
  currency: string;
  period: string;
  annual_income: string | number;
  published_at: string | null;
  effective_date: string | null;
  fetched_at: string;
  payload: string | null;
  created_at: string;
}

function parsePayload(payload: string | null): Record<string, unknown> | null {
  if (!payload) {
    return null;
  }

  try {
    const parsed = JSON.parse(payload);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return null;
    }
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  }
}

function mapRow(row: IncomeBenchmarkSnapshotRow): IncomeBenchmarkSnapshot {
  return {
    id: row.id,
    source: row.source,
    region: row.region,
    currency: row.currency,
    period: 'annual',
    annualIncome: Number(row.annual_income ?? 0),
    publishedAt: row.published_at,
    effectiveDate: row.effective_date,
    fetchedAt: row.fetched_at,
    payload: parsePayload(row.payload),
    createdAt: row.created_at,
  };
}

export class IncomeBenchmarkRepository {
  async findLatest(region: string, currency: string): Promise<IncomeBenchmarkSnapshot | null> {
    const row = await db<IncomeBenchmarkSnapshotRow>('income_benchmark_snapshots')
      .where('region', region)
      .andWhere('currency', currency)
      .orderBy('fetched_at', 'desc')
      .first();

    return row ? mapRow(row) : null;
  }

  async create(input: {
    source: string;
    region: string;
    currency: string;
    annualIncome: number;
    publishedAt?: string | null;
    effectiveDate?: string | null;
    payload?: Record<string, unknown> | null;
  }): Promise<IncomeBenchmarkSnapshot> {
    const now = new Date().toISOString();
    const row: IncomeBenchmarkSnapshotRow = {
      id: randomUUID(),
      source: input.source,
      region: input.region,
      currency: input.currency,
      period: 'annual',
      annual_income: input.annualIncome,
      published_at: input.publishedAt ?? null,
      effective_date: input.effectiveDate ?? null,
      fetched_at: now,
      payload: input.payload ? JSON.stringify(input.payload) : null,
      created_at: now,
    };

    await db('income_benchmark_snapshots').insert(row);
    return mapRow(row);
  }
}

