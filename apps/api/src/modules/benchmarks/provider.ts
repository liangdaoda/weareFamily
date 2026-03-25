import { env } from '../../config/env';
import type { IncomeBenchmarkSourceMeta } from './model';

export type IncomeBenchmarkFetchFailureReason =
  | 'not_configured'
  | 'timeout'
  | 'http'
  | 'html'
  | 'invalid_json'
  | 'json_schema'
  | 'network';

export interface IncomeBenchmarkProviderPayload {
  annualIncome: number;
  currency: string | null;
  region: string | null;
  source: string | null;
  publishedAt: string | null;
  effectiveDate: string | null;
  payload: Record<string, unknown>;
  sourceMeta: IncomeBenchmarkSourceMeta | null;
}

export type IncomeBenchmarkProviderFetchResult =
  | { ok: true; data: IncomeBenchmarkProviderPayload }
  | { ok: false; reason: IncomeBenchmarkFetchFailureReason; statusCode?: number };

export interface IncomeBenchmarkProvider {
  kind: 'nbs' | 'url';
  fetchLatest(signal: AbortSignal): Promise<IncomeBenchmarkProviderFetchResult>;
}

interface UrlProviderOptions {
  url: string;
  source: string;
  region: string;
  currency: string;
  fetchImpl?: typeof fetch;
}

interface NbsProviderOptions {
  endpoint: string;
  dbCode: string;
  indicator: string;
  source: string;
  region: string;
  currency: string;
  fetchImpl?: typeof fetch;
}

function toIsoDate(value: unknown): string | null {
  if (!value) {
    return null;
  }

  const parsed = new Date(String(value));
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed.toISOString();
}

function pickNumber(payload: Record<string, unknown>, keys: string[]): number | null {
  for (const key of keys) {
    const value = payload[key];
    if (value === undefined || value === null) {
      continue;
    }

    const parsed = Number(String(value).replace(/,/g, '').trim());
    if (Number.isFinite(parsed) && parsed > 0) {
      return parsed;
    }
  }
  return null;
}

function pickString(payload: Record<string, unknown>, keys: string[]): string | null {
  for (const key of keys) {
    const value = payload[key];
    if (value === undefined || value === null) {
      continue;
    }
    const text = String(value).trim();
    if (text) {
      return text;
    }
  }
  return null;
}

function resolveObject(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function parsePositiveNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value) && value > 0) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number(value.replace(/,/g, '').trim());
    if (Number.isFinite(parsed) && parsed > 0) {
      return parsed;
    }
  }
  return null;
}

function parseYear(value: unknown): number | null {
  const text = String(value ?? '').trim();
  const matched = text.match(/^(\d{4})$/);
  if (!matched) {
    return null;
  }
  return Number(matched[1]);
}

function isLikelyHtml(text: string): boolean {
  const trimmed = text.trim().toLowerCase();
  return trimmed.startsWith('<!doctype') || trimmed.startsWith('<html') || trimmed.startsWith('<');
}

function parseNodeYear(node: Record<string, unknown>): number | null {
  const wds = Array.isArray(node.wds) ? node.wds : [];
  for (const item of wds) {
    const wd = resolveObject(item);
    if (!wd) {
      continue;
    }
    if (wd.wdcode === 'sj') {
      const parsed = parseYear(wd.valuecode);
      if (parsed !== null) {
        return parsed;
      }
    }
  }

  const code = String(node.code ?? '');
  const matched = code.match(/_sj\.(\d{4})$/);
  if (!matched) {
    return null;
  }
  return Number(matched[1]);
}

export function normalizeUrlPayload(
  payload: Record<string, unknown>,
): {
  annualIncome: number | null;
  currency: string | null;
  region: string | null;
  source: string | null;
  publishedAt: string | null;
  effectiveDate: string | null;
} {
  const nestedData = resolveObject(payload.data);
  const target = nestedData ?? payload;

  return {
    annualIncome: pickNumber(target, ['annualIncome', 'annual_income', 'incomeAnnual', 'income']),
    currency: pickString(target, ['currency', 'currencyCode']),
    region: pickString(target, ['region', 'country', 'location']),
    source: pickString(target, ['source', 'provider', 'name']),
    publishedAt: toIsoDate(target.publishedAt ?? target.published_at ?? target.date),
    effectiveDate: toIsoDate(target.effectiveDate ?? target.effective_date ?? target.asOf),
  };
}

export function parseNbsIncomePayload(
  payload: Record<string, unknown>,
  indicator: string,
): { annualIncome: number; year: number } | null {
  const returned = resolveObject(payload.returndata);
  const datanodes = Array.isArray(returned?.datanodes) ? returned.datanodes : [];
  if (datanodes.length === 0) {
    return null;
  }

  let latestYear = 0;
  let latestIncome: number | null = null;
  for (const item of datanodes) {
    const node = resolveObject(item);
    if (!node) {
      continue;
    }

    const code = String(node.code ?? '');
    if (code && !code.includes(`zb.${indicator}_`)) {
      continue;
    }

    const year = parseNodeYear(node);
    if (year === null) {
      continue;
    }

    const data = resolveObject(node.data);
    const value = parsePositiveNumber(data?.data ?? data?.strdata);
    if (value === null) {
      continue;
    }

    if (year > latestYear) {
      latestYear = year;
      latestIncome = value;
    }
  }

  if (latestYear <= 0 || latestIncome === null) {
    return null;
  }

  return {
    annualIncome: latestIncome,
    year: latestYear,
  };
}

export class UrlIncomeBenchmarkProvider implements IncomeBenchmarkProvider {
  readonly kind = 'url' as const;
  private readonly fetchImpl: typeof fetch;

  constructor(private readonly options: UrlProviderOptions) {
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async fetchLatest(signal: AbortSignal): Promise<IncomeBenchmarkProviderFetchResult> {
    if (!this.options.url) {
      return { ok: false, reason: 'not_configured' };
    }

    let response: Response;
    try {
      response = await this.fetchImpl(this.options.url, {
        method: 'GET',
        signal,
      });
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        return { ok: false, reason: 'timeout' };
      }
      return { ok: false, reason: 'network' };
    }

    if (!response.ok) {
      return {
        ok: false,
        reason: 'http',
        statusCode: response.status,
      };
    }

    const text = await response.text();
    if (isLikelyHtml(text)) {
      return { ok: false, reason: 'html' };
    }

    let raw: Record<string, unknown>;
    try {
      const parsed = JSON.parse(text) as unknown;
      const obj = resolveObject(parsed);
      if (!obj) {
        return { ok: false, reason: 'json_schema' };
      }
      raw = obj;
    } catch {
      return { ok: false, reason: 'invalid_json' };
    }

    const normalized = normalizeUrlPayload(raw);
    if (!normalized.annualIncome) {
      return { ok: false, reason: 'json_schema' };
    }

    return {
      ok: true,
      data: {
        annualIncome: normalized.annualIncome,
        currency: normalized.currency ?? this.options.currency,
        region: normalized.region ?? this.options.region,
        source: normalized.source ?? this.options.source,
        publishedAt: normalized.publishedAt,
        effectiveDate: normalized.effectiveDate,
        payload: raw,
        sourceMeta: {
          provider: 'url',
          indicator: null,
          year: null,
        },
      },
    };
  }
}

export class NbsIncomeBenchmarkProvider implements IncomeBenchmarkProvider {
  readonly kind = 'nbs' as const;
  private readonly fetchImpl: typeof fetch;

  constructor(private readonly options: NbsProviderOptions) {
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async fetchLatest(signal: AbortSignal): Promise<IncomeBenchmarkProviderFetchResult> {
    const requestBody = new URLSearchParams({
      m: 'QueryData',
      dbcode: this.options.dbCode,
      rowcode: 'zb',
      colcode: 'sj',
      wds: '[]',
      dfwds: JSON.stringify([{ wdcode: 'zb', valuecode: this.options.indicator }]),
      k1: Date.now().toString(),
    });

    let response: Response;
    try {
      response = await this.fetchImpl(this.options.endpoint, {
        method: 'POST',
        headers: {
          Referer: 'https://data.stats.gov.cn/easyquery.htm?cn=A01',
          'X-Requested-With': 'XMLHttpRequest',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: requestBody.toString(),
        signal,
      });
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        return { ok: false, reason: 'timeout' };
      }
      return { ok: false, reason: 'network' };
    }

    if (!response.ok) {
      return {
        ok: false,
        reason: 'http',
        statusCode: response.status,
      };
    }

    const text = await response.text();
    if (isLikelyHtml(text)) {
      return { ok: false, reason: 'html' };
    }

    let raw: Record<string, unknown>;
    try {
      const parsed = JSON.parse(text) as unknown;
      const obj = resolveObject(parsed);
      if (!obj) {
        return { ok: false, reason: 'json_schema' };
      }
      raw = obj;
    } catch {
      return { ok: false, reason: 'invalid_json' };
    }

    const parsedNbs = parseNbsIncomePayload(raw, this.options.indicator);
    if (!parsedNbs) {
      return { ok: false, reason: 'json_schema' };
    }

    return {
      ok: true,
      data: {
        annualIncome: parsedNbs.annualIncome,
        currency: this.options.currency,
        region: this.options.region,
        source: this.options.source,
        publishedAt: null,
        effectiveDate: new Date(Date.UTC(parsedNbs.year, 11, 31)).toISOString(),
        payload: raw,
        sourceMeta: {
          provider: 'nbs',
          indicator: this.options.indicator,
          year: parsedNbs.year,
        },
      },
    };
  }
}

export function createIncomeBenchmarkProviderFromEnv(
  fetchImpl?: typeof fetch,
): IncomeBenchmarkProvider {
  if (env.benchmarkProvider === 'url') {
    return new UrlIncomeBenchmarkProvider({
      url: env.benchmarkIncomeUrl,
      source: env.benchmarkSource,
      region: env.benchmarkRegion,
      currency: env.benchmarkCurrency,
      fetchImpl,
    });
  }

  return new NbsIncomeBenchmarkProvider({
    endpoint: env.benchmarkNbsEndpoint,
    dbCode: env.benchmarkNbsDbCode,
    indicator: env.benchmarkNbsIndicator,
    source: env.benchmarkSource,
    region: env.benchmarkRegion,
    currency: env.benchmarkCurrency,
    fetchImpl,
  });
}
