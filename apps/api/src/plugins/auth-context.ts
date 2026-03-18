// Authentication context derived from JWT or headers.
import fp from 'fastify-plugin';
import type { FastifyPluginAsync, FastifyRequest } from 'fastify';

import { env, type UserRole } from '../config/env';
import { verifyAccessToken } from '../modules/auth/service';
import type { UserContext } from '../types/user-context';

const allowedRoles = new Set<UserRole>(['broker', 'consumer', 'admin']);
const publicPaths = new Set<string>([
  '/health',
  '/api/v1/auth/login',
  '/api/v1/auth/register',
  '/api/v1/auth/sso/callback',
]);

interface RequestWithContext extends FastifyRequest {
  _userContext?: UserContext;
}

function sanitizePath(url: string): string {
  return url.split('?')[0];
}

function contextFromHeaders(request: { headers: Record<string, unknown> }): UserContext {
  const headerRole = String(request.headers['x-user-role'] ?? 'consumer').toLowerCase();
  const role: UserRole = allowedRoles.has(headerRole as UserRole)
    ? (headerRole as UserRole)
    : 'consumer';

  const tenantId = env.tenantMode === 'private'
    ? env.defaultTenantId
    : String(request.headers['x-tenant-id'] ?? env.defaultTenantId);

  return {
    userId: String(request.headers['x-user-id'] ?? 'user-consumer-demo'),
    role,
    tenantId,
    tenantMode: env.tenantMode,
  };
}

const authContextPlugin: FastifyPluginAsync = async (app) => {
  const defaultContext: UserContext = {
    userId: '',
    role: 'consumer',
    tenantId: env.defaultTenantId,
    tenantMode: env.tenantMode,
  };

  // Use getter/setter to avoid reference-type decorator errors.
  app.decorateRequest('userContext', {
    getter(this: RequestWithContext) {
      return this._userContext ?? defaultContext;
    },
    setter(this: RequestWithContext, value: UserContext) {
      this._userContext = value;
    },
  });

  app.addHook('onRequest', async (request, reply) => {
    if (request.method === 'OPTIONS') {
      return;
    }

    const path = sanitizePath(request.url);
    const authHeader = Array.isArray(request.headers.authorization)
      ? request.headers.authorization[0]
      : request.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.replace('Bearer ', '').trim();
      try {
        const payload = verifyAccessToken(token);
        if (env.tenantMode === 'private' && payload.tenantId !== env.defaultTenantId) {
          await reply.code(403).send({ message: 'Tenant mismatch.' });
          return;
        }

        request.userContext = {
          userId: payload.sub,
          role: payload.role,
          tenantId: payload.tenantId,
          tenantMode: payload.tenantMode,
        };
        return;
      } catch (error) {
        if (env.authRequired && !publicPaths.has(path)) {
          await reply.code(401).send({ message: 'Invalid token.' });
          return;
        }
      }
    }

    if (env.authRequired && !publicPaths.has(path)) {
      await reply.code(401).send({ message: 'Unauthorized.' });
      return;
    }

    // Dev fallback to header-based identity for non-authenticated requests.
    request.userContext = contextFromHeaders(request);
  });
};

export default fp(authContextPlugin, {
  name: 'auth-context',
});
