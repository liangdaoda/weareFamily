// Domain model types for policies.
import type { PolicyCoverageItem, PolicyFeatureSignals, PolicyInsight } from './insight';
import type { ValueDimension } from '../value-analysis/model';

export type PolicyStatus = 'active' | 'pending' | 'expired' | 'cancelled';
export type PolicyRenewalStatus = 'not_due' | 'due_soon' | 'in_progress' | 'completed' | 'expired';

export interface PolicyAiPayload {
  signals?: Partial<PolicyFeatureSignals> | null;
  coverageItems?: PolicyCoverageItem[] | null;
}

export interface Policy {
  id: string;
  tenantId: string;
  familyId: string;
  policyNo: string;
  insurerName: string;
  productName: string;
  premium: number;
  currency: string;
  status: PolicyStatus;
  startDate: string;
  endDate: string | null;
  aiRiskScore: number | null;
  aiNotes: string | null;
  aiPayload?: PolicyAiPayload | null;
  aiInsight?: PolicyInsight;
  renewalStatus: PolicyRenewalStatus;
  assigneeUserId: string | null;
  lifecycleNote: string | null;
  lifecycleUpdatedAt: string | null;
  valueScore?: number | null;
  valueConfidence?: number | null;
  valueSummary?: string | null;
  valueDimensions?: ValueDimension[] | null;
  valueReasons?: string[] | null;
  valueRecommendations?: string[] | null;
  valueScoringVersion?: string | null;
  valueNeedsReview?: boolean;
  createdByUserId: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreatePolicyInput {
  familyId: string;
  policyNo: string;
  insurerName: string;
  productName: string;
  premium: number;
  currency?: string;
  status?: PolicyStatus;
  startDate: string;
  endDate?: string | null;
  aiRiskScore?: number | null;
  aiNotes?: string | null;
  aiPayload?: PolicyAiPayload | null;
}

export interface ListPoliciesInput {
  status?: PolicyStatus;
}
