// Authentication endpoints: login, SSO callback, and current user.
import type { FastifyPluginAsync } from 'fastify';
import bcrypt from 'bcryptjs';

import { env, type UserRole } from '../../config/env';
import { AuthRepository } from './repository';
import { signAccessToken } from './service';

const allowedRoles = new Set<UserRole>(['broker', 'consumer', 'admin']);

interface LoginBody {
  email: string;
  password: string;
  tenantId?: string;
}

interface SsoBody {
  provider: string;
  subject: string;
  email: string;
  name?: string;
  role?: UserRole;
  tenantId?: string;
}

function assertLoginBody(body: unknown): LoginBody {
  if (!body || typeof body !== 'object') {
    throw new Error('Invalid payload: request body must be an object.');
  }

  const payload = body as Partial<LoginBody>;
  if (!payload.email || !payload.password) {
    throw new Error('Invalid payload: email and password are required.');
  }

  return {
    email: String(payload.email),
    password: String(payload.password),
    tenantId: payload.tenantId ? String(payload.tenantId) : undefined,
  };
}

function assertSsoBody(body: unknown): SsoBody {
  if (!body || typeof body !== 'object') {
    throw new Error('Invalid payload: request body must be an object.');
  }

  const payload = body as Partial<SsoBody>;
  if (!payload.provider || !payload.subject || !payload.email) {
    throw new Error('Invalid payload: provider, subject, and email are required.');
  }

  const role = payload.role && allowedRoles.has(payload.role) ? payload.role : 'consumer';

  return {
    provider: String(payload.provider),
    subject: String(payload.subject),
    email: String(payload.email),
    name: payload.name ? String(payload.name) : 'SSO ÓÃ»§',
    role,
    tenantId: payload.tenantId ? String(payload.tenantId) : undefined,
  };
}

function resolveTenantId(tenantId?: string): string {
  if (env.tenantMode === 'private') {
    return env.defaultTenantId;
  }
  if (!tenantId) {
    throw new Error('Missing tenantId for SaaS mode.');
  }
  return tenantId;
}

const authRoutes: FastifyPluginAsync = async (app) => {
  const repository = new AuthRepository();

  app.post('/login', async (request, reply) => {
    try {
      const body = assertLoginBody(request.body);
      const tenantId = resolveTenantId(body.tenantId);
      const user = await repository.findByEmail(tenantId, body.email);

      if (!user || !user.passwordHash) {
        return reply.code(401).send({ message: 'Invalid credentials.' });
      }

      const ok = await bcrypt.compare(body.password, user.passwordHash);
      if (!ok) {
        return reply.code(401).send({ message: 'Invalid credentials.' });
      }

      const token = signAccessToken({
        sub: user.id,
        role: user.role,
        tenantId: user.tenantId,
        tenantMode: env.tenantMode,
        name: user.name,
        email: user.email,
      });

      return reply.send({
        accessToken: token,
        tokenType: 'Bearer',
        expiresIn: env.jwtExpiresIn,
        user: {
          id: user.id,
          role: user.role,
          name: user.name,
          email: user.email,
          tenantId: user.tenantId,
        },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Invalid request body.';
      return reply.code(400).send({ message });
    }
  });

  app.post('/sso/callback', async (request, reply) => {
    try {
      const body = assertSsoBody(request.body);
      const tenantId = resolveTenantId(body.tenantId);

      let user = await repository.findByProvider(tenantId, body.provider, body.subject);
      if (!user) {
        // In production, you should validate provider tokens before creating users.
        user = await repository.createUser({
          tenantId,
          role: body.role ?? 'consumer',
          name: body.name ?? body.email,
          email: body.email,
          externalProvider: body.provider,
          externalSubject: body.subject,
        });
      }

      const token = signAccessToken({
        sub: user.id,
        role: user.role,
        tenantId: user.tenantId,
        tenantMode: env.tenantMode,
        name: user.name,
        email: user.email,
      });

      return reply.send({
        accessToken: token,
        tokenType: 'Bearer',
        expiresIn: env.jwtExpiresIn,
        user: {
          id: user.id,
          role: user.role,
          name: user.name,
          email: user.email,
          tenantId: user.tenantId,
        },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Invalid request body.';
      return reply.code(400).send({ message });
    }
  });

  app.get('/me', async (request) => {
    return {
      userId: request.userContext.userId,
      role: request.userContext.role,
      tenantId: request.userContext.tenantId,
      tenantMode: request.userContext.tenantMode,
    };
  });
};

export default authRoutes;
