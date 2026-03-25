import { randomUUID } from 'node:crypto';

import { db } from '../../db/knex';
import type { UserContext } from '../../types/user-context';
import type { OpsTask, OpsTaskPriority, OpsTaskStatus, OpsTaskType } from './model';

interface OpsTaskRow {
  id: string;
  tenant_id: string;
  family_id: string;
  policy_id: string | null;
  document_id: string | null;
  task_type: string;
  status: string;
  priority: string;
  title: string;
  description: string | null;
  payload: string | null;
  assigned_user_id: string | null;
  created_by_user_id: string;
  due_at: string | null;
  closed_at: string | null;
  created_at: string;
  updated_at: string;
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

function mapRow(row: OpsTaskRow): OpsTask {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    familyId: row.family_id,
    policyId: row.policy_id,
    documentId: row.document_id,
    taskType: row.task_type as OpsTaskType,
    status: row.status as OpsTaskStatus,
    priority: row.priority as OpsTaskPriority,
    title: row.title,
    description: row.description,
    payload: parsePayload(row.payload),
    assignedUserId: row.assigned_user_id,
    createdByUserId: row.created_by_user_id,
    dueAt: row.due_at,
    closedAt: row.closed_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export class OpsTaskRepository {
  async list(
    ctx: UserContext,
    filters: {
      status?: OpsTaskStatus;
      taskType?: OpsTaskType;
      familyId?: string;
    },
  ): Promise<OpsTask[]> {
    const query = db<OpsTaskRow>('ops_tasks').where('tenant_id', ctx.tenantId);
    if (filters.status) {
      query.andWhere('status', filters.status);
    }
    if (filters.taskType) {
      query.andWhere('task_type', filters.taskType);
    }
    if (filters.familyId) {
      query.andWhere('family_id', filters.familyId);
    }

    if (ctx.role === 'consumer') {
      const ownedFamilies = db('families')
        .select('id')
        .where('tenant_id', ctx.tenantId)
        .andWhere('owner_user_id', ctx.userId);
      query.whereIn('family_id', ownedFamilies);
    }

    const rows = await query.orderBy([
      { column: 'status', order: 'asc' },
      { column: 'priority', order: 'desc' },
      { column: 'due_at', order: 'asc' },
      { column: 'updated_at', order: 'desc' },
    ]);
    return rows.map(mapRow);
  }

  async findById(ctx: UserContext, taskId: string): Promise<OpsTask | null> {
    const query = db<OpsTaskRow>('ops_tasks')
      .where('tenant_id', ctx.tenantId)
      .andWhere('id', taskId);

    if (ctx.role === 'consumer') {
      const ownedFamilies = db('families')
        .select('id')
        .where('tenant_id', ctx.tenantId)
        .andWhere('owner_user_id', ctx.userId);
      query.whereIn('family_id', ownedFamilies);
    }

    const row = await query.first();
    return row ? mapRow(row) : null;
  }

  async create(input: {
    tenantId: string;
    familyId: string;
    policyId?: string | null;
    documentId?: string | null;
    taskType: OpsTaskType;
    priority: OpsTaskPriority;
    title: string;
    description?: string | null;
    payload?: Record<string, unknown> | null;
    assignedUserId?: string | null;
    createdByUserId: string;
    dueAt?: string | null;
  }): Promise<OpsTask> {
    const now = new Date().toISOString();
    const row: OpsTaskRow = {
      id: randomUUID(),
      tenant_id: input.tenantId,
      family_id: input.familyId,
      policy_id: input.policyId ?? null,
      document_id: input.documentId ?? null,
      task_type: input.taskType,
      status: 'open',
      priority: input.priority,
      title: input.title,
      description: input.description ?? null,
      payload: input.payload ? JSON.stringify(input.payload) : null,
      assigned_user_id: input.assignedUserId ?? null,
      created_by_user_id: input.createdByUserId,
      due_at: input.dueAt ?? null,
      closed_at: null,
      created_at: now,
      updated_at: now,
    };

    await db('ops_tasks').insert(row);
    return mapRow(row);
  }

  async createIfNotOpen(input: {
    tenantId: string;
    familyId: string;
    policyId?: string | null;
    documentId?: string | null;
    taskType: OpsTaskType;
    priority: OpsTaskPriority;
    title: string;
    description?: string | null;
    payload?: Record<string, unknown> | null;
    assignedUserId?: string | null;
    createdByUserId: string;
    dueAt?: string | null;
  }): Promise<OpsTask> {
    const query = db<OpsTaskRow>('ops_tasks')
      .where('tenant_id', input.tenantId)
      .andWhere('family_id', input.familyId)
      .andWhere('task_type', input.taskType)
      .whereIn('status', ['open', 'in_progress']);

    if (input.policyId) {
      query.andWhere('policy_id', input.policyId);
    } else {
      query.whereNull('policy_id');
    }

    if (input.documentId) {
      query.andWhere('document_id', input.documentId);
    }

    const existing = await query.first();
    if (existing) {
      return mapRow(existing);
    }

    return this.create(input);
  }

  async updateStatus(
    ctx: UserContext,
    taskId: string,
    input: {
      status: OpsTaskStatus;
      assignedUserId?: string | null;
      description?: string | null;
    },
  ): Promise<OpsTask | null> {
    const now = new Date().toISOString();
    const updates: Record<string, unknown> = {
      status: input.status,
      updated_at: now,
    };
    if (input.assignedUserId !== undefined) {
      updates.assigned_user_id = input.assignedUserId;
    }
    if (input.description !== undefined) {
      updates.description = input.description;
    }
    if (input.status === 'done' || input.status === 'cancelled') {
      updates.closed_at = now;
    } else {
      updates.closed_at = null;
    }

    const query = db<OpsTaskRow>('ops_tasks')
      .where('tenant_id', ctx.tenantId)
      .andWhere('id', taskId);

    if (ctx.role === 'consumer') {
      const ownedFamilies = db('families')
        .select('id')
        .where('tenant_id', ctx.tenantId)
        .andWhere('owner_user_id', ctx.userId);
      query.whereIn('family_id', ownedFamilies);
    }

    const updatedCount = await query.update(updates);
    if (updatedCount === 0) {
      return null;
    }

    const row = await db<OpsTaskRow>('ops_tasks')
      .where('tenant_id', ctx.tenantId)
      .andWhere('id', taskId)
      .first();
    return row ? mapRow(row) : null;
  }
}

