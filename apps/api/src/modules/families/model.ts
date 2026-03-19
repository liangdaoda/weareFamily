// Family domain models for members and documents.
export interface Family {
  id: string;
  tenantId: string;
  name: string;
  ownerUserId: string;
}

export interface FamilyMember {
  id: string;
  familyId: string;
  tenantId: string;
  name: string;
  relation: string;
  gender: string | null;
  birthDate: string | null;
  phone: string | null;
  createdAt: string;
}

export interface CreateFamilyMemberInput {
  name: string;
  relation: string;
  gender?: string | null;
  birthDate?: string | null;
  phone?: string | null;
}

export interface UpdateFamilyMemberInput {
  name: string;
  relation: string;
  gender?: string | null;
  birthDate?: string | null;
  phone?: string | null;
}

export interface FamilyDocument {
  id: string;
  familyId: string;
  tenantId: string;
  policyId: string | null;
  fileName: string;
  storagePath: string;
  mimeType: string;
  fileSize: number;
  docType: string;
  uploadedByUserId: string;
  createdAt: string;
}
