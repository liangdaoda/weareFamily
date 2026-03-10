// Repository for user authentication data.
import { randomUUID } from 'node:crypto';

import { db } from '../../db/knex';
import type { UserRole } from '../../config/env';
import type { AuthUser } from './types';

interface UserRow {
  id: string;
  tenant_id: string;
  role: string;
  name: string;
  email: string;
  password_hash: string | null;
  external_provider: string | null;
  external_subject: string | null;
}

function mapRow(row: UserRow): AuthUser {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    role: row.role as UserRole,
    name: row.name,
    email: row.email,
    passwordHash: row.password_hash,
    externalProvider: row.external_provider,
    externalSubject: row.external_subject,
  };
}

export class AuthRepository {
  async findByEmail(tenantId: string, email: string): Promise<AuthUser | null> {
    const row = await db<UserRow>('users')
      .where('tenant_id', tenantId)
      .andWhere('email', email)
      .first();
    return row ? mapRow(row) : null;
  }

  async findByProvider(
    tenantId: string,
    provider: string,
    subject: string,
  ): Promise<AuthUser | null> {
    const row = await db<UserRow>('users')
      .where('tenant_id', tenantId)
      .andWhere('external_provider', provider)
      .andWhere('external_subject', subject)
      .first();
    return row ? mapRow(row) : null;
  }

  async createUser(input: {
    tenantId: string;
    role: UserRole;
    name: string;
    email: string;
    passwordHash?: string | null;
    externalProvider?: string | null;
    externalSubject?: string | null;
  }): Promise<AuthUser> {
    const payload: UserRow = {
      id: randomUUID(),
      tenant_id: input.tenantId,
      role: input.role,
      name: input.name,
      email: input.email,
      password_hash: input.passwordHash ?? null,
      external_provider: input.externalProvider ?? null,
      external_subject: input.externalSubject ?? null,
    };

    await db('users').insert(payload);
    return mapRow(payload);
  }
}
