import assert from 'node:assert/strict';
import test from 'node:test';

import type { IncomeBenchmarkSnapshot } from '../src/modules/benchmarks/model';
import type {
  IncomeBenchmarkProvider,
  IncomeBenchmarkProviderFetchResult,
} from '../src/modules/benchmarks/provider';
import { IncomeBenchmarkService } from '../src/modules/benchmarks/service';

interface CreateInput {
  source: string;
  region: string;
  currency: string;
  annualIncome: number;
  publishedAt?: string | null;
  effectiveDate?: string | null;
  payload?: Record<string, unknown> | null;
}

class MemoryRepository {
  latest: IncomeBenchmarkSnapshot | null;
  createCount = 0;

  constructor(snapshot: IncomeBenchmarkSnapshot | null) {
    this.latest = snapshot;
  }

  async findLatest(_region: string, _currency: string): Promise<IncomeBenchmarkSnapshot | null> {
    return this.latest;
  }

  async create(input: CreateInput): Promise<IncomeBenchmarkSnapshot> {
    this.createCount += 1;
    const snapshot: IncomeBenchmarkSnapshot = {
      id: `snap-${this.createCount}`,
      source: input.source,
      region: input.region,
      currency: input.currency,
      period: 'annual',
      annualIncome: input.annualIncome,
      publishedAt: input.publishedAt ?? null,
      effectiveDate: input.effectiveDate ?? null,
      fetchedAt: '2026-03-25T00:00:00.000Z',
      payload: input.payload ?? null,
      createdAt: '2026-03-25T00:00:00.000Z',
    };
    this.latest = snapshot;
    return snapshot;
  }
}

class StubProvider implements IncomeBenchmarkProvider {
  readonly kind = 'nbs' as const;
  called = 0;

  constructor(private readonly result: IncomeBenchmarkProviderFetchResult) {}

  async fetchLatest(_signal: AbortSignal): Promise<IncomeBenchmarkProviderFetchResult> {
    this.called += 1;
    return this.result;
  }
}

function makeSnapshot(input: {
  id: string;
  fetchedAt: string;
  annualIncome: number;
  source?: string;
  payload?: Record<string, unknown> | null;
}): IncomeBenchmarkSnapshot {
  return {
    id: input.id,
    source: input.source ?? 'nbs-hgnd-a0a0101',
    region: 'CN',
    currency: 'CNY',
    period: 'annual',
    annualIncome: input.annualIncome,
    publishedAt: null,
    effectiveDate: null,
    fetchedAt: input.fetchedAt,
    payload: input.payload ?? null,
    createdAt: input.fetchedAt,
  };
}

test('refreshIfStale should skip provider call when snapshot is fresh', async () => {
  const now = new Date('2026-03-25T00:00:00.000Z');
  const repo = new MemoryRepository(
    makeSnapshot({
      id: 'snap-fresh',
      fetchedAt: '2026-03-24T18:00:00.000Z',
      annualIncome: 40000,
    }),
  );

  const provider = new StubProvider({ ok: false, reason: 'network' });
  const service = new IncomeBenchmarkService({
    repository: repo,
    provider,
    now: () => now,
  });

  const current = await service.refreshIfStale(false);
  assert.equal(provider.called, 0);
  assert.equal(current.stale, false);
  assert.equal(current.snapshot.id, 'snap-fresh');
});

test('refreshIfStale should persist new snapshot when stale and provider succeeds', async () => {
  const now = new Date('2026-03-25T00:00:00.000Z');
  const repo = new MemoryRepository(
    makeSnapshot({
      id: 'snap-stale',
      fetchedAt: '2026-03-01T00:00:00.000Z',
      annualIncome: 38000,
    }),
  );

  const provider = new StubProvider({
    ok: true,
    data: {
      annualIncome: 43377,
      currency: 'CNY',
      region: 'CN',
      source: 'nbs-hgnd-a0a0101',
      publishedAt: null,
      effectiveDate: '2025-12-31T00:00:00.000Z',
      payload: { returndata: { datanodes: [] } },
      sourceMeta: {
        provider: 'nbs',
        indicator: 'A0A0101',
        year: 2025,
      },
    },
  });

  const service = new IncomeBenchmarkService({
    repository: repo,
    provider,
    now: () => now,
  });

  const refreshed = await service.refreshIfStale(false);
  assert.equal(provider.called, 1);
  assert.equal(repo.createCount, 1);
  assert.equal(refreshed.stale, false);
  assert.equal(refreshed.snapshot.annualIncome, 43377);
  assert.deepEqual(refreshed.sourceMeta, {
    provider: 'nbs',
    indicator: 'A0A0101',
    year: 2025,
  });
});

test('refreshIfStale should return stale snapshot when provider fails', async () => {
  const now = new Date('2026-03-25T00:00:00.000Z');
  const repo = new MemoryRepository(
    makeSnapshot({
      id: 'snap-old',
      fetchedAt: '2026-03-01T00:00:00.000Z',
      annualIncome: 39000,
      payload: {
        sourceMeta: {
          provider: 'nbs',
          indicator: 'A0A0101',
          year: 2024,
        },
      },
    }),
  );

  const provider = new StubProvider({ ok: false, reason: 'timeout' });
  const service = new IncomeBenchmarkService({
    repository: repo,
    provider,
    now: () => now,
  });

  const current = await service.refreshIfStale(false);
  assert.equal(provider.called, 1);
  assert.equal(repo.createCount, 0);
  assert.equal(current.stale, true);
  assert.equal(current.snapshot.id, 'snap-old');
});

test('getCurrent should seed default value when snapshot does not exist', async () => {
  const now = new Date('2026-03-25T00:00:00.000Z');
  const repo = new MemoryRepository(null);
  const provider = new StubProvider({ ok: false, reason: 'network' });
  const service = new IncomeBenchmarkService({
    repository: repo,
    provider,
    now: () => now,
  });

  const current = await service.getCurrent();
  assert.equal(repo.createCount, 1);
  assert.equal(current.stale, false);
  assert.equal(current.snapshot.annualIncome, 36000);
  assert.deepEqual(current.sourceMeta, {
    provider: 'seed',
    indicator: null,
    year: 2026,
  });
});
