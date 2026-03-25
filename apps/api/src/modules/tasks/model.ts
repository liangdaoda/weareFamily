export type OpsTaskType =
  | 'renewal_due'
  | 'document_review'
  | 'value_low_confidence'
  | 'missing_data';

export type OpsTaskStatus = 'open' | 'in_progress' | 'done' | 'cancelled';
export type OpsTaskPriority = 'low' | 'medium' | 'high';

export interface OpsTask {
  id: string;
  tenantId: string;
  familyId: string;
  policyId: string | null;
  documentId: string | null;
  taskType: OpsTaskType;
  status: OpsTaskStatus;
  priority: OpsTaskPriority;
  title: string;
  description: string | null;
  payload: Record<string, unknown> | null;
  assignedUserId: string | null;
  createdByUserId: string;
  dueAt: string | null;
  closedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

