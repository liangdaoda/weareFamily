// Family endpoints for members and PDF documents.
import { createReadStream } from 'node:fs';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

import type { FastifyPluginAsync } from 'fastify';

import { env } from '../../config/env';
import { PolicyRepository } from '../policies/repository';
import { scanPolicyFromPdf } from '../policies/scan';
import { FamilyRepository } from './repository';
import type { CreateFamilyMemberInput } from './model';

function assertMemberBody(body: unknown): CreateFamilyMemberInput {
  if (!body || typeof body !== 'object') {
    throw new Error('Invalid payload: request body must be an object.');
  }

  const payload = body as Partial<CreateFamilyMemberInput>;
  if (!payload.name || !payload.relation) {
    throw new Error('Invalid payload: name and relation are required.');
  }

  return {
    name: String(payload.name),
    relation: String(payload.relation),
    gender: payload.gender ? String(payload.gender) : null,
    birthDate: payload.birthDate ? String(payload.birthDate) : null,
    phone: payload.phone ? String(payload.phone) : null,
  };
}

function sanitizeFilename(fileName: string): string {
  return path.basename(fileName).replace(/[^a-zA-Z0-9._-]/g, '_');
}

function isPdfFile(fileName: string, mimeType: string): boolean {
  return fileName.toLowerCase().endsWith('.pdf') || mimeType.toLowerCase().includes('pdf');
}

function looksLikePolicy(scan: Awaited<ReturnType<typeof scanPolicyFromPdf>>): boolean {
  const hasPolicyNo = Boolean(scan.policyNo && !scan.policyNo.startsWith('AUTO-'));
  const hasInsurer = Boolean(scan.insurerName && scan.insurerName !== '未知保险公司');
  const hasProduct = Boolean(scan.productName && scan.productName !== '未识别产品');
  const hasPremium = scan.premium > 0;
  const hasStartDate = Boolean(scan.startDate && /^\d{4}-\d{2}-\d{2}$/.test(scan.startDate));

  const coreScore = Number(hasPolicyNo) + Number(hasInsurer) + Number(hasProduct);
  const totalScore = coreScore + Number(hasPremium) + Number(hasStartDate);

  return coreScore >= 2 && totalScore >= 3;
}

const familyRoutes: FastifyPluginAsync = async (app) => {
  const repository = new FamilyRepository();
  const policyRepository = new PolicyRepository();

  app.get('/', async (request) => {
    const items = await repository.listFamilies(request.userContext);
    return { total: items.length, items };
  });

  app.get('/:familyId/members', async (request, reply) => {
    const familyId = (request.params as { familyId: string }).familyId;
    const family = await repository.ensureFamilyAccess(request.userContext, familyId);
    if (!family) {
      return reply.code(404).send({ message: 'Family not found.' });
    }

    const members = await repository.listMembers(request.userContext, familyId);
    return { total: members.length, items: members };
  });

  app.post('/:familyId/members', async (request, reply) => {
    const familyId = (request.params as { familyId: string }).familyId;
    const family = await repository.ensureFamilyAccess(request.userContext, familyId);
    if (!family) {
      return reply.code(404).send({ message: 'Family not found.' });
    }

    if (request.userContext.role === 'consumer' && family.ownerUserId !== request.userContext.userId) {
      return reply.code(403).send({ message: 'Forbidden.' });
    }

    try {
      const input = assertMemberBody(request.body);
      const created = await repository.addMember(request.userContext, familyId, input);
      return reply.code(201).send(created);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Invalid request body.';
      return reply.code(400).send({ message });
    }
  });

  app.get('/:familyId/documents', async (request, reply) => {
    const familyId = (request.params as { familyId: string }).familyId;
    const family = await repository.ensureFamilyAccess(request.userContext, familyId);
    if (!family) {
      return reply.code(404).send({ message: 'Family not found.' });
    }

    const items = await repository.listDocuments(request.userContext, familyId);
    return { total: items.length, items };
  });

  app.post('/:familyId/documents', async (request, reply) => {
    const familyId = (request.params as { familyId: string }).familyId;
    const family = await repository.ensureFamilyAccess(request.userContext, familyId);
    if (!family) {
      return reply.code(404).send({ message: 'Family not found.' });
    }

    if (request.userContext.role === 'consumer' && family.ownerUserId !== request.userContext.userId) {
      return reply.code(403).send({ message: 'Forbidden.' });
    }

    const file = await request.file();
    if (!file) {
      return reply.code(400).send({ message: 'Missing file upload.' });
    }

    if (!isPdfFile(file.filename || '', file.mimetype || '')) {
      return reply.code(400).send({ message: '仅支持PDF文件。' });
    }

    await mkdir(env.uploadDir, { recursive: true });

    const buffer = await file.toBuffer();
    const scan = await scanPolicyFromPdf(buffer, file.filename || 'policy.pdf');

    if (!looksLikePolicy(scan)) {
      return reply.code(400).send({
        message: '未识别到有效保单信息，请上传标准保单PDF。',
      });
    }

    const safeName = sanitizeFilename(file.filename || 'policy.pdf');
    const storedName = `${Date.now()}_${safeName}`;
    const targetPath = path.join(env.uploadDir, storedName);

    await writeFile(targetPath, buffer);

    const fields = file.fields as Record<string, { value: string }> | undefined;
    const policyId = fields?.policyId?.value ? String(fields.policyId.value) : null;
    const docType = fields?.docType?.value ? String(fields.docType.value) : 'policy-form';

    const createdPolicy = await policyRepository.createPolicy(request.userContext, {
      familyId,
      policyNo: scan.policyNo,
      insurerName: scan.insurerName,
      productName: scan.productName,
      premium: scan.premium,
      currency: scan.currency,
      status: 'active',
      startDate: scan.startDate,
      endDate: scan.endDate,
      aiRiskScore: scan.aiRiskScore,
      aiNotes: scan.aiNotes,
    });

    const created = await repository.createDocument(request.userContext, {
      familyId,
      policyId: policyId ?? createdPolicy.id,
      fileName: file.filename,
      storagePath: storedName,
      mimeType: file.mimetype || 'application/pdf',
      fileSize: buffer.length,
      docType,
    });

    return reply.code(201).send({
      document: created,
      policy: createdPolicy,
      scan: {
        source: scan.source,
        policyNo: scan.policyNo,
        insurerName: scan.insurerName,
        productName: scan.productName,
        premium: scan.premium,
        currency: scan.currency,
        startDate: scan.startDate,
        endDate: scan.endDate,
      },
    });
  });

  app.get('/:familyId/documents/:documentId/download', async (request, reply) => {
    const { familyId, documentId } = request.params as { familyId: string; documentId: string };
    const family = await repository.ensureFamilyAccess(request.userContext, familyId);
    if (!family) {
      return reply.code(404).send({ message: 'Family not found.' });
    }

    const document = await repository.findDocument(request.userContext, documentId);
    if (!document || document.familyId !== familyId) {
      return reply.code(404).send({ message: 'Document not found.' });
    }

    const filePath = path.join(env.uploadDir, sanitizeFilename(document.storagePath));
    reply.header('Content-Disposition', `inline; filename="${document.fileName}"`);
    reply.type(document.mimeType);
    return reply.send(createReadStream(filePath));
  });
};

export default familyRoutes;
