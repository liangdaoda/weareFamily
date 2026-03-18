// Authentication endpoints: login, register, SSO callback, and current user.
import type { FastifyPluginAsync } from 'fastify';
import bcrypt from 'bcryptjs';

import { env, type UserRole } from '../../config/env';
import { FamilyRepository } from '../families/repository';
import { AuthRepository } from './repository';
import { signAccessToken } from './service';

const allowedRoles = new Set<UserRole>(['broker', 'consumer', 'admin']);
const registerRoles = new Set<UserRole>(['broker', 'consumer']);

interface LoginBody {
  email: string;
  password: string;
  tenantId?: string;
}

interface RegisterBody {
  email: string;
  password: string;
  name: string;
  role?: UserRole;
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

function assertRegisterBody(body: unknown): RegisterBody {
  if (!body || typeof body !== 'object') {
    throw new Error('Invalid payload: request body must be an object.');
  }

  const payload = body as Partial<RegisterBody>;
  if (!payload.email || !payload.password || !payload.name) {
    throw new Error('Invalid payload: email, password, and name are required.');
  }

  const email = String(payload.email).trim();
  const name = String(payload.name).trim();
  const password = String(payload.password);

  const emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
  if (!emailRegex.test(email)) {
    throw new Error('Invalid payload: email format is invalid.');
  }

  if (name.length < 2 || name.length > 40) {
    throw new Error('Invalid payload: name must be 2-40 characters.');
  }

  if (password.length < 8 || !/[a-zA-Z]/.test(password) || !/\d/.test(password)) {
    throw new Error('Invalid payload: password must be at least 8 characters and include letters and numbers.');
  }

  const role = payload.role && registerRoles.has(payload.role) ? payload.role : 'consumer';

  return {
    email,
    password,
    name,
    role,
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
    name: payload.name ? String(payload.name) : 'SSO 用户',
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
  const familyRepository = new FamilyRepository();

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

  // Email + password registration for broker/consumer users.
  app.post('/register', async (request, reply) => {
    try {
      const body = assertRegisterBody(request.body);
      const tenantId = resolveTenantId(body.tenantId);

      const existing = await repository.findByEmail(tenantId, body.email);
      if (existing) {
        return reply.code(409).send({ message: '该邮箱已注册，请直接登录。' });
      }

      const passwordHash = await bcrypt.hash(body.password, 10);
      const user = await repository.createUser({
        tenantId,
        role: body.role ?? 'consumer',
        name: body.name,
        email: body.email,
        passwordHash,
      });

      if (user.role === 'consumer') {
        await familyRepository.createFamily({
          tenantId: user.tenantId,
          ownerUserId: user.id,
          name: `${user.name}的家庭`,
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

      return reply.code(201).send({
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
