// Domain model types for policies.
import type { PolicyCoverageItem, PolicyFeatureSignals, PolicyInsight } from './insight';

export type PolicyStatus = 'active' | 'pending' | 'expired' | 'cancelled';

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
