import type { FastifyPluginAsync } from 'fastify';

import type { OpsTaskStatus, OpsTaskType } from './model';
import { OpsTaskRepository } from './repository';

const allowedStatuses = new Set<OpsTaskStatus>(['open', 'in_progress', 'done', 'cancelled']);
const allowedTypes = new Set<OpsTaskType>(['renewal_due', 'document_review', 'value_low_confidence', 'missing_data']);

const taskRoutes: FastifyPluginAsync = async (app) => {
  const repository = new OpsTaskRepository();

  app.get('/', async (request) => {
    const query = request.query as {
      status?: string;
      taskType?: string;
      familyId?: string;
    };

    const tasks = await repository.list(request.userContext, {
      status: query.status && allowedStatuses.has(query.status as OpsTaskStatus)
        ? (query.status as OpsTaskStatus)
        : undefined,
      taskType: query.taskType && allowedTypes.has(query.taskType as OpsTaskType)
        ? (query.taskType as OpsTaskType)
        : undefined,
      familyId: query.familyId ? String(query.familyId) : undefined,
    });

    return {
      total: tasks.length,
      items: tasks,
    };
  });

  app.patch('/:taskId', async (request, reply) => {
    const { taskId } = request.params as { taskId: string };
    const body = request.body as {
      status?: OpsTaskStatus;
      assignedUserId?: string | null;
      description?: string | null;
    } | null;

    if (!body || !body.status || !allowedStatuses.has(body.status)) {
      return reply.code(400).send({ message: 'Invalid task status.' });
    }

    const updated = await repository.updateStatus(request.userContext, taskId, {
      status: body.status,
      assignedUserId: body.assignedUserId,
      description: body.description,
    });
    if (!updated) {
      return reply.code(404).send({ message: 'Task not found.' });
    }

    return updated;
  });
};

export default taskRoutes;

