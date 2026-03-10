// Extend Fastify request type with user context.
import 'fastify';
import type { UserContext } from './user-context';

declare module 'fastify' {
  interface FastifyRequest {
    userContext: UserContext;
  }
}
