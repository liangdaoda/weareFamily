// Request-scoped user and tenant metadata.
import type { TenantMode, UserRole } from '../config/env';

export interface UserContext {
  userId: string;
  role: UserRole;
  tenantId: string;
  tenantMode: TenantMode;
}
