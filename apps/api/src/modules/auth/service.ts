// JWT signing and verification helpers.
import { sign, verify, type JwtPayload, type SignOptions } from 'jsonwebtoken';

import { env, type TenantMode, type UserRole } from '../../config/env';
import type { AccessTokenPayload } from './types';

const allowedRoles = new Set<UserRole>(['broker', 'consumer', 'admin']);
const allowedTenantModes = new Set<TenantMode>(['saas', 'private']);

export function signAccessToken(payload: AccessTokenPayload): string {
  const expiresIn = env.jwtExpiresIn as SignOptions['expiresIn'];
  return sign(payload, env.jwtSecret, {
    issuer: env.jwtIssuer,
    expiresIn,
  });
}

export function verifyAccessToken(token: string): AccessTokenPayload {
  const decoded = verify(token, env.jwtSecret, {
    issuer: env.jwtIssuer,
  });

  if (typeof decoded === 'string') {
    throw new Error('Invalid token payload.');
  }

  const payload = decoded as JwtPayload;
  const required = ['sub', 'role', 'tenantId', 'tenantMode', 'name', 'email'];
  for (const field of required) {
    if (!payload[field]) {
      throw new Error(`Token missing field: ${field}`);
    }
  }

  if (!allowedRoles.has(String(payload.role) as UserRole)) {
    throw new Error('Invalid role in token.');
  }
  if (!allowedTenantModes.has(String(payload.tenantMode) as TenantMode)) {
    throw new Error('Invalid tenant mode in token.');
  }

  return {
    sub: String(payload.sub),
    role: String(payload.role) as AccessTokenPayload['role'],
    tenantId: String(payload.tenantId),
    tenantMode: String(payload.tenantMode) as AccessTokenPayload['tenantMode'],
    name: String(payload.name),
    email: String(payload.email),
  };
}
