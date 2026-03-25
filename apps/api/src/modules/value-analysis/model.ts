export type ValueDimensionKey =
  | 'coverageAdequacy'
  | 'affordability'
  | 'termsQuality'
  | 'waiverCompleteness'
  | 'renewalStability';

export interface ValueDimension {
  key: ValueDimensionKey;
  weight: number;
  score: number;
  reason: string;
}

export interface PolicyValueAnalysis {
  id: string;
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
  createdAt: string;
  updatedAt: string;
}

