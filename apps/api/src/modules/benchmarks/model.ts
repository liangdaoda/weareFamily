export interface IncomeBenchmarkSnapshot {
  id: string;
  source: string;
  region: string;
  currency: string;
  period: 'annual';
  annualIncome: number;
  publishedAt: string | null;
  effectiveDate: string | null;
  fetchedAt: string;
  payload: Record<string, unknown> | null;
  createdAt: string;
}

export interface IncomeBenchmarkSourceMeta {
  provider: string;
  indicator: string | null;
  year: number | null;
}

export interface CurrentIncomeBenchmark {
  snapshot: IncomeBenchmarkSnapshot;
  stale: boolean;
  sourceMeta: IncomeBenchmarkSourceMeta | null;
}
