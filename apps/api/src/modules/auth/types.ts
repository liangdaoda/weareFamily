// Authentication domain types and JWT payload.
import type { TenantMode, UserRole } from '../../config/env';

export interface AuthUser {
  id: string;
  tenantId: string;
  role: UserRole;
  name: string;
  email: string;
  passwordHash: string | null;
  externalProvider: string | null;
  externalSubject: string | null;
}

export interface AccessTokenPayload {
  sub: string;
  role: UserRole;
  tenantId: string;
  tenantMode: TenantMode;
  name: string;
  email: string;
}
