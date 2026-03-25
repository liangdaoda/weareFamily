// Repository for families, members, and documents.
import { randomUUID } from 'node:crypto';

import { db } from '../../db/knex';
import type { UserContext } from '../../types/user-context';
import type {
  CreateFamilyMemberInput,
  Family,
  FamilyDocument,
  FamilyMember,
  UpdateFamilyMemberInput,
} from './model';

interface FamilyRow {
  id: string;
  tenant_id: string;
  name: string;
  owner_user_id: string;
}

interface MemberRow {
  id: string;
  tenant_id: string;
  family_id: string;
  name: string;
  relation: string;
  gender: string | null;
  birth_date: string | null;
  phone: string | null;
  created_at: string;
}

interface DocumentRow {
  id: string;
  tenant_id: string;
  family_id: string;
  policy_id: string | null;
  file_name: string;
  storage_path: string;
  mime_type: string;
  file_size: number | string;
  doc_type: string;
  review_status: string;
  review_notes: string | null;
  reviewed_by_user_id: string | null;
  reviewed_at: string | null;
  uploaded_by_user_id: string;
  created_at: string;
}

function mapFamily(row: FamilyRow): Family {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    name: row.name,
    ownerUserId: row.owner_user_id,
  };
}

function mapMember(row: MemberRow): FamilyMember {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    familyId: row.family_id,
    name: row.name,
    relation: row.relation,
    gender: row.gender,
    birthDate: row.birth_date,
    phone: row.phone,
    createdAt: row.created_at,
  };
}

function mapDocument(row: DocumentRow): FamilyDocument {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    familyId: row.family_id,
    policyId: row.policy_id,
    fileName: row.file_name,
    storagePath: row.storage_path,
    mimeType: row.mime_type,
    fileSize: Number(row.file_size ?? 0),
    docType: row.doc_type,
    reviewStatus: row.review_status as FamilyDocument['reviewStatus'],
    reviewNotes: row.review_notes,
    reviewedByUserId: row.reviewed_by_user_id,
    reviewedAt: row.reviewed_at,
    uploadedByUserId: row.uploaded_by_user_id,
    createdAt: row.created_at,
  };
}

export class FamilyRepository {
  async listFamilies(ctx: UserContext): Promise<Family[]> {
    const query = db<FamilyRow>('families').where('tenant_id', ctx.tenantId);
    if (ctx.role === 'consumer') {
      query.andWhere('owner_user_id', ctx.userId);
    }
    const rows = await query.orderBy('created_at', 'desc');
    return rows.map(mapFamily);
  }

  // Create a default family for a newly registered consumer.
  async createFamily(input: {
    tenantId: string;
    ownerUserId: string;
    name?: string;
  }): Promise<Family> {
    const payload: FamilyRow = {
      id: randomUUID(),
      tenant_id: input.tenantId,
      name: input.name ?? '我的家庭',
      owner_user_id: input.ownerUserId,
    };

    await db('families').insert(payload);
    return mapFamily(payload);
  }

  async ensureFamilyAccess(ctx: UserContext, familyId: string): Promise<Family | null> {
    const query = db<FamilyRow>('families').where('tenant_id', ctx.tenantId).andWhere('id', familyId);
    if (ctx.role === 'consumer') {
      query.andWhere('owner_user_id', ctx.userId);
    }
    const row = await query.first();
    return row ? mapFamily(row) : null;
  }

  async listMembers(ctx: UserContext, familyId: string): Promise<FamilyMember[]> {
    const rows = await db<MemberRow>('family_members')
      .where('tenant_id', ctx.tenantId)
      .andWhere('family_id', familyId)
      .orderBy('created_at', 'asc');
    return rows.map(mapMember);
  }

  async addMember(ctx: UserContext, familyId: string, input: CreateFamilyMemberInput): Promise<FamilyMember> {
    const payload: MemberRow = {
      id: randomUUID(),
      tenant_id: ctx.tenantId,
      family_id: familyId,
      name: input.name,
      relation: input.relation,
      gender: input.gender ?? null,
      birth_date: input.birthDate ?? null,
      phone: input.phone ?? null,
      created_at: new Date().toISOString(),
    };

    await db('family_members').insert(payload);
    return mapMember(payload);
  }

  async findMember(ctx: UserContext, memberId: string): Promise<FamilyMember | null> {
    const row = await db<MemberRow>('family_members')
      .where('tenant_id', ctx.tenantId)
      .andWhere('id', memberId)
      .first();
    return row ? mapMember(row) : null;
  }

  async updateMember(ctx: UserContext, memberId: string, input: UpdateFamilyMemberInput): Promise<FamilyMember | null> {
    await db<MemberRow>('family_members')
      .where('tenant_id', ctx.tenantId)
      .andWhere('id', memberId)
      .update({
        name: input.name,
        relation: input.relation,
        gender: input.gender ?? null,
        birth_date: input.birthDate ?? null,
        phone: input.phone ?? null,
      });

    const row = await db<MemberRow>('family_members')
      .where('tenant_id', ctx.tenantId)
      .andWhere('id', memberId)
      .first();
    return row ? mapMember(row) : null;
  }

  // Delete one member under current tenant scope.
  async deleteMember(ctx: UserContext, memberId: string): Promise<boolean> {
    const deleted = await db<MemberRow>('family_members')
      .where('tenant_id', ctx.tenantId)
      .andWhere('id', memberId)
      .delete();
    return deleted > 0;
  }

  async listDocuments(ctx: UserContext, familyId: string): Promise<FamilyDocument[]> {
    const rows = await db<DocumentRow>('policy_documents')
      .where('tenant_id', ctx.tenantId)
      .andWhere('family_id', familyId)
      .orderBy('created_at', 'desc');
    return rows.map(mapDocument);
  }

  async createDocument(ctx: UserContext, input: {
    familyId: string;
    policyId?: string | null;
    fileName: string;
    storagePath: string;
    mimeType: string;
    fileSize: number;
    docType?: string;
    reviewStatus?: FamilyDocument['reviewStatus'];
    reviewNotes?: string | null;
    reviewedByUserId?: string | null;
    reviewedAt?: string | null;
  }): Promise<FamilyDocument> {
    const payload: DocumentRow = {
      id: randomUUID(),
      tenant_id: ctx.tenantId,
      family_id: input.familyId,
      policy_id: input.policyId ?? null,
      file_name: input.fileName,
      storage_path: input.storagePath,
      mime_type: input.mimeType,
      file_size: input.fileSize,
      doc_type: input.docType ?? 'policy-form',
      review_status: input.reviewStatus ?? 'pending',
      review_notes: input.reviewNotes ?? null,
      reviewed_by_user_id: input.reviewedByUserId ?? null,
      reviewed_at: input.reviewedAt ?? null,
      uploaded_by_user_id: ctx.userId,
      created_at: new Date().toISOString(),
    };

    await db('policy_documents').insert(payload);
    return mapDocument(payload);
  }

  async findDocument(ctx: UserContext, documentId: string): Promise<FamilyDocument | null> {
    const row = await db<DocumentRow>('policy_documents')
      .where('tenant_id', ctx.tenantId)
      .andWhere('id', documentId)
      .first();
    return row ? mapDocument(row) : null;
  }

  async countDocumentsByPolicy(ctx: UserContext, familyId: string, policyId: string): Promise<number> {
    const row = await db<DocumentRow>('policy_documents')
      .where('tenant_id', ctx.tenantId)
      .andWhere('family_id', familyId)
      .andWhere('policy_id', policyId)
      .count<{ total: number | string }>({ total: 'id' })
      .first();
    return Number(row?.total ?? 0);
  }

  async deleteDocument(ctx: UserContext, documentId: string): Promise<boolean> {
    const deleted = await db<DocumentRow>('policy_documents')
      .where('tenant_id', ctx.tenantId)
      .andWhere('id', documentId)
      .delete();
    return deleted > 0;
  }
}
