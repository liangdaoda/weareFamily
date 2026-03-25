import { env } from '../../config/env';
import type {
  CurrentIncomeBenchmark,
  IncomeBenchmarkSnapshot,
  IncomeBenchmarkSourceMeta,
} from './model';
import {
  createIncomeBenchmarkProviderFromEnv,
  type IncomeBenchmarkProvider,
  type IncomeBenchmarkProviderFetchResult,
} from './provider';
import { IncomeBenchmarkRepository } from './repository';

const defaultPeriodHours = 24 * 7;

type IncomeBenchmarkCreateInput = Parameters<IncomeBenchmarkRepository['create']>[0];

interface IncomeBenchmarkRepositoryPort {
  findLatest(region: string, currency: string): Promise<IncomeBenchmarkSnapshot | null>;
  create(input: IncomeBenchmarkCreateInput): Promise<IncomeBenchmarkSnapshot>;
}

interface IncomeBenchmarkLogger {
  info(payload: Record<string, unknown>, message: string): void;
  warn(payload: Record<string, unknown>, message: string): void;
}

interface IncomeBenchmarkServiceOptions {
  repository?: IncomeBenchmarkRepositoryPort;
  provider?: IncomeBenchmarkProvider;
  logger?: IncomeBenchmarkLogger;
  now?: () => Date;
}

const noopLogger: IncomeBenchmarkLogger = {
  info: () => undefined,
  warn: () => undefined,
};

function resolveObject(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function isSnapshotStale(snapshot: IncomeBenchmarkSnapshot, now: Date): boolean {
  const fetched = new Date(snapshot.fetchedAt);
  if (Number.isNaN(fetched.getTime())) {
    return true;
  }
  const elapsed = now.getTime() - fetched.getTime();
  const thresholdMs = Math.max(1, env.benchmarkFetchIntervalHours || defaultPeriodHours) * 60 * 60 * 1000;
  return elapsed >= thresholdMs;
}

function toSnapshotYear(snapshot: IncomeBenchmarkSnapshot): number | null {
  const candidates = [snapshot.effectiveDate, snapshot.publishedAt, snapshot.fetchedAt];
  for (const candidate of candidates) {
    if (!candidate) {
      continue;
    }
    const date = new Date(candidate);
    if (!Number.isNaN(date.getTime())) {
      return date.getUTCFullYear();
    }
  }
  return null;
}

function readStoredSourceMeta(payload: Record<string, unknown> | null): IncomeBenchmarkSourceMeta | null {
  const wrapped = resolveObject(payload?.sourceMeta);
  if (!wrapped) {
    return null;
  }

  const provider = typeof wrapped.provider === 'string' ? wrapped.provider : null;
  if (!provider) {
    return null;
  }

  return {
    provider,
    indicator: typeof wrapped.indicator === 'string' ? wrapped.indicator : null,
    year: typeof wrapped.year === 'number' && Number.isFinite(wrapped.year) ? wrapped.year : null,
  };
}

function inferSourceMeta(
  snapshot: IncomeBenchmarkSnapshot,
  providerKind: 'nbs' | 'url',
): IncomeBenchmarkSourceMeta | null {
  const stored = readStoredSourceMeta(snapshot.payload);
  if (stored) {
    return stored;
  }

  const year = toSnapshotYear(snapshot);
  if (snapshot.source.includes('seed')) {
    return {
      provider: 'seed',
      indicator: null,
      year,
    };
  }

  const inferredProvider = snapshot.source.startsWith('nbs-') ? 'nbs' : providerKind;
  return {
    provider: inferredProvider,
    indicator: inferredProvider === 'nbs' ? env.benchmarkNbsIndicator : null,
    year,
  };
}

function wrapPayload(
  rawPayload: Record<string, unknown>,
  sourceMeta: IncomeBenchmarkSourceMeta | null,
): Record<string, unknown> {
  return {
    sourceMeta,
    raw: rawPayload,
  };
}

export class IncomeBenchmarkService {
  private readonly repository: IncomeBenchmarkRepositoryPort;
  private readonly provider: IncomeBenchmarkProvider;
  private readonly logger: IncomeBenchmarkLogger;
  private readonly now: () => Date;

  constructor(options: IncomeBenchmarkServiceOptions = {}) {
    this.repository = options.repository ?? new IncomeBenchmarkRepository();
    this.provider = options.provider ?? createIncomeBenchmarkProviderFromEnv();
    this.logger = options.logger ?? noopLogger;
    this.now = options.now ?? (() => new Date());
  }

  async getCurrent(): Promise<CurrentIncomeBenchmark> {
    const latest = await this.repository.findLatest(env.benchmarkRegion, env.benchmarkCurrency);
    if (latest) {
      return {
        snapshot: latest,
        stale: isSnapshotStale(latest, this.now()),
        sourceMeta: inferSourceMeta(latest, this.provider.kind),
      };
    }

    const seeded = await this.repository.create({
      source: env.benchmarkSource,
      region: env.benchmarkRegion,
      currency: env.benchmarkCurrency,
      annualIncome: env.benchmarkDefaultAnnualIncome,
      publishedAt: this.now().toISOString(),
      effectiveDate: this.now().toISOString(),
      payload: {
        sourceMeta: {
          provider: 'seed',
          indicator: null,
          year: this.now().getUTCFullYear(),
        },
        raw: null,
      },
    });

    return {
      snapshot: seeded,
      stale: false,
      sourceMeta: {
        provider: 'seed',
        indicator: null,
        year: this.now().getUTCFullYear(),
      },
    };
  }

  async refreshIfStale(force = false): Promise<CurrentIncomeBenchmark> {
    const current = await this.getCurrent();
    if (!force && !current.stale) {
      return current;
    }

    const fetched = await this.fetchFromProvider();
    if (!fetched.ok) {
      this.logger.warn(
        {
          provider: this.provider.kind,
          reason: fetched.reason,
          statusCode: fetched.statusCode ?? null,
          stale: true,
        },
        'Income benchmark fetch failed. Reusing latest snapshot.',
      );

      return {
        snapshot: current.snapshot,
        stale: true,
        sourceMeta: current.sourceMeta,
      };
    }

    const created = await this.repository.create({
      source: fetched.data.source ?? env.benchmarkSource,
      region: fetched.data.region ?? env.benchmarkRegion,
      currency: fetched.data.currency ?? env.benchmarkCurrency,
      annualIncome: fetched.data.annualIncome,
      publishedAt: fetched.data.publishedAt,
      effectiveDate: fetched.data.effectiveDate,
      payload: wrapPayload(fetched.data.payload, fetched.data.sourceMeta),
    });

    this.logger.info(
      {
        provider: this.provider.kind,
        indicator: fetched.data.sourceMeta?.indicator ?? null,
        year: fetched.data.sourceMeta?.year ?? null,
        annualIncome: fetched.data.annualIncome,
        stale: false,
      },
      'Income benchmark refreshed.',
    );

    return {
      snapshot: created,
      stale: false,
      sourceMeta: fetched.data.sourceMeta ?? inferSourceMeta(created, this.provider.kind),
    };
  }

  private async fetchFromProvider(): Promise<IncomeBenchmarkProviderFetchResult> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), env.benchmarkTimeoutMs);

    try {
      return await this.provider.fetchLatest(controller.signal);
    } catch {
      return { ok: false, reason: 'network' };
    } finally {
      clearTimeout(timeout);
    }
  }
}

export function startIncomeBenchmarkScheduler(
  service: IncomeBenchmarkService,
  options?: { onError?: (error: unknown) => void },
): NodeJS.Timeout | null {
  if (!env.benchmarkSchedulerEnabled) {
    return null;
  }

  const periodMs = Math.max(1, env.benchmarkFetchIntervalHours || defaultPeriodHours) * 60 * 60 * 1000;
  const timer = setInterval(() => {
    void service.refreshIfStale(false).catch((error) => {
      if (options?.onError) {
        options.onError(error);
      }
    });
  }, periodMs);
  timer.unref();
  return timer;
}
