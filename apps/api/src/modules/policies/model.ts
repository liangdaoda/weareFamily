// Domain model types for policies.
export type PolicyStatus = 'active' | 'pending' | 'expired' | 'cancelled';

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
}

export interface ListPoliciesInput {
  status?: PolicyStatus;
}
