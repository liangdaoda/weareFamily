// Family endpoints for members and PDF documents.
import { createReadStream } from 'node:fs';
import { mkdir, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';

import type { FastifyPluginAsync } from 'fastify';

import { env } from '../../config/env';
import { IncomeBenchmarkService } from '../benchmarks/service';
import { PolicyRepository } from '../policies/repository';
import { buildPolicyAiOutput, resolveInsightLocale } from '../policies/insight';
import { scanPolicyFromPdf } from '../policies/scan';
import { OpsTaskRepository } from '../tasks/repository';
import { PolicyValueAnalysisService } from '../value-analysis/service';
import { buildFamilyInsight } from './insight';
import { FamilyRepository } from './repository';
import type { CreateFamilyMemberInput, UpdateFamilyMemberInput } from './model';

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

function assertMemberUpdateBody(body: unknown): UpdateFamilyMemberInput {
  return assertMemberBody(body);
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

function calculateExtractionConfidence(scan: Awaited<ReturnType<typeof scanPolicyFromPdf>>): number {
  const checkpoints = [
    Boolean(scan.policyNo && !scan.policyNo.startsWith('AUTO-')),
    Boolean(scan.insurerName && scan.insurerName !== '未知保险公司'),
    Boolean(scan.productName && scan.productName !== '未识别产品'),
    scan.premium > 0,
    Boolean(scan.startDate && /^\d{4}-\d{2}-\d{2}$/.test(scan.startDate)),
    Array.isArray(scan.coverageItems) && scan.coverageItems.length > 0,
  ];

  const hit = checkpoints.filter(Boolean).length;
  return Number((hit / checkpoints.length).toFixed(2));
}

async function removeStoredFile(storagePath: string): Promise<void> {
  const filePath = path.join(env.uploadDir, sanitizeFilename(storagePath));
  try {
    await unlink(filePath);
  } catch (error) {
    const errno = error as NodeJS.ErrnoException;
    if (errno.code === 'ENOENT') {
      return;
    }
    throw error;
  }
}

const familyRoutes: FastifyPluginAsync = async (app) => {
  const repository = new FamilyRepository();
  const policyRepository = new PolicyRepository();
  const benchmarkService = new IncomeBenchmarkService({ logger: app.log });
  const valueService = new PolicyValueAnalysisService();
  const taskRepository = new OpsTaskRepository();

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

  app.get('/:familyId/insights', async (request, reply) => {
    const familyId = (request.params as { familyId: string }).familyId;
    const family = await repository.ensureFamilyAccess(request.userContext, familyId);
    if (!family) {
      return reply.code(404).send({ message: 'Family not found.' });
    }

    const locale = resolveInsightLocale(request.headers);
    const [members, policies, benchmark] = await Promise.all([
      repository.listMembers(request.userContext, familyId),
      policyRepository.listPoliciesByFamily(request.userContext, familyId),
      benchmarkService.refreshIfStale(false),
    ]);

    const insight = buildFamilyInsight({
      familyId,
      locale,
      members,
      policies,
      benchmarkAnnualIncome: benchmark.snapshot.annualIncome,
      benchmarkAsOf: benchmark.snapshot.fetchedAt,
    });
    return insight;
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

  app.patch('/:familyId/members/:memberId', async (request, reply) => {
    const { familyId, memberId } = request.params as { familyId: string; memberId: string };
    const family = await repository.ensureFamilyAccess(request.userContext, familyId);
    if (!family) {
      return reply.code(404).send({ message: 'Family not found.' });
    }

    if (request.userContext.role === 'consumer' && family.ownerUserId !== request.userContext.userId) {
      return reply.code(403).send({ message: 'Forbidden.' });
    }

    const member = await repository.findMember(request.userContext, memberId);
    if (!member || member.familyId !== familyId) {
      return reply.code(404).send({ message: 'Family member not found.' });
    }

    try {
      const input = assertMemberUpdateBody(request.body);
      const updated = await repository.updateMember(request.userContext, memberId, input);
      if (!updated) {
        return reply.code(404).send({ message: 'Family member not found.' });
      }
      return reply.send(updated);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Invalid request body.';
      return reply.code(400).send({ message });
    }
  });

  app.delete('/:familyId/members/:memberId', async (request, reply) => {
    const { familyId, memberId } = request.params as { familyId: string; memberId: string };
    const family = await repository.ensureFamilyAccess(request.userContext, familyId);
    if (!family) {
      return reply.code(404).send({ message: 'Family not found.' });
    }

    if (request.userContext.role === 'consumer' && family.ownerUserId !== request.userContext.userId) {
      return reply.code(403).send({ message: 'Forbidden.' });
    }

    const member = await repository.findMember(request.userContext, memberId);
    if (!member || member.familyId !== familyId) {
      return reply.code(404).send({ message: 'Family member not found.' });
    }

    const deleted = await repository.deleteMember(request.userContext, memberId);
    if (!deleted) {
      return reply.code(404).send({ message: 'Family member not found.' });
    }

    return reply.code(204).send();
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
    const locale = resolveInsightLocale(request.headers);
    const extractionConfidence = calculateExtractionConfidence(scan);

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

    // Persist Chinese AI notes and return localized notes based on request locale.
    const storageAi = buildPolicyAiOutput(
      {
        policyNo: scan.policyNo,
        insurerName: scan.insurerName,
        productName: scan.productName,
        premium: scan.premium,
        currency: scan.currency,
        status: 'active',
        startDate: scan.startDate,
        endDate: scan.endDate,
        aiNotes: scan.aiNotes,
        signals: scan.signals,
        coverageItems: scan.coverageItems,
      },
      'zh',
    );

    const responseAi = locale === 'zh'
      ? storageAi
      : buildPolicyAiOutput(
          {
            policyNo: scan.policyNo,
            insurerName: scan.insurerName,
            productName: scan.productName,
            premium: scan.premium,
            currency: scan.currency,
            status: 'active',
            startDate: scan.startDate,
            endDate: scan.endDate,
            aiNotes: scan.aiNotes,
            signals: scan.signals,
            coverageItems: scan.coverageItems,
          },
          locale,
        );

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
      aiRiskScore: storageAi.aiRiskScore,
      aiNotes: storageAi.aiNotes,
      aiPayload: {
        signals: scan.signals,
        coverageItems: storageAi.aiInsight.coverageItems,
      },
    });

    const benchmark = await benchmarkService.refreshIfStale(false);
    const valueAnalysis = await valueService.refreshForPolicy({
      ctx: request.userContext,
      policy: createdPolicy,
      annualIncome: benchmark.snapshot.annualIncome,
      locale,
      triggerUserId: request.userContext.userId,
    });

    const reviewStatus: 'needs_review' | 'success' =
      extractionConfidence < 0.65 || valueAnalysis.valueConfidence < 0.65
      ? 'needs_review'
      : 'success';

    const created = await repository.createDocument(request.userContext, {
      familyId,
      policyId: policyId ?? createdPolicy.id,
      fileName: file.filename,
      storagePath: storedName,
      mimeType: file.mimetype || 'application/pdf',
      fileSize: buffer.length,
      docType,
      reviewStatus,
      reviewNotes: reviewStatus === 'needs_review'
        ? '自动识别置信度较低，建议人工复核。'
        : '自动识别通过。',
      reviewedByUserId: reviewStatus === 'success' ? request.userContext.userId : null,
      reviewedAt: reviewStatus === 'success' ? new Date().toISOString() : null,
    });

    if (reviewStatus === 'needs_review') {
      await taskRepository.createIfNotOpen({
        tenantId: request.userContext.tenantId,
        familyId,
        policyId: createdPolicy.id,
        documentId: created.id,
        taskType: 'document_review',
        priority: 'high',
        title: '保单PDF识别待复核',
        description: '文档抽取结果置信度较低，请人工核对关键信息。',
        payload: {
          documentId: created.id,
          extractionConfidence,
          valueConfidence: valueAnalysis.valueConfidence,
        },
        createdByUserId: request.userContext.userId,
        dueAt: new Date(Date.now() + 86400000).toISOString(),
      });
    }

    if (createdPolicy.renewalStatus === 'due_soon') {
      await taskRepository.createIfNotOpen({
        tenantId: request.userContext.tenantId,
        familyId,
        policyId: createdPolicy.id,
        taskType: 'renewal_due',
        priority: 'high',
        title: '保单进入30天续保窗口',
        description: '建议尽快处理续保并复核责任条款变化。',
        createdByUserId: request.userContext.userId,
        dueAt: createdPolicy.endDate,
      });
    }

    return reply.code(201).send({
      document: created,
      policy: {
        ...createdPolicy,
        aiRiskScore: responseAi.aiRiskScore,
        aiNotes: responseAi.aiNotes,
        aiInsight: responseAi.aiInsight,
        valueScore: valueAnalysis.valueScore,
        valueConfidence: valueAnalysis.valueConfidence,
        valueSummary: valueAnalysis.summary,
        valueDimensions: valueAnalysis.dimensions,
        valueReasons: valueAnalysis.reasons,
        valueRecommendations: valueAnalysis.recommendations,
        valueScoringVersion: valueAnalysis.scoringVersion,
        valueNeedsReview: valueAnalysis.valueConfidence < 0.65,
      },
      scan: {
        source: scan.source,
        policyNo: scan.policyNo,
        insurerName: scan.insurerName,
        productName: scan.productName,
        premium: scan.premium,
        currency: scan.currency,
        startDate: scan.startDate,
        endDate: scan.endDate,
        coverageItems: responseAi.aiInsight.coverageItems,
        extractionConfidence,
        reviewStatus,
      },
    });
  });

  app.delete('/:familyId/documents/:documentId', async (request, reply) => {
    const { familyId, documentId } = request.params as { familyId: string; documentId: string };
    const family = await repository.ensureFamilyAccess(request.userContext, familyId);
    if (!family) {
      return reply.code(404).send({ message: 'Family not found.' });
    }

    if (request.userContext.role === 'consumer' && family.ownerUserId !== request.userContext.userId) {
      return reply.code(403).send({ message: 'Forbidden.' });
    }

    const document = await repository.findDocument(request.userContext, documentId);
    if (!document || document.familyId !== familyId) {
      return reply.code(404).send({ message: 'Document not found.' });
    }

    const deleted = await repository.deleteDocument(request.userContext, documentId);
    if (!deleted) {
      return reply.code(404).send({ message: 'Document not found.' });
    }

    let deletedPolicyId: string | null = null;
    if (document.policyId) {
      const remainingDocs = await repository.countDocumentsByPolicy(
        request.userContext,
        familyId,
        document.policyId,
      );
      if (remainingDocs === 0) {
        const deletedPolicy = await policyRepository.deletePolicyByFamily(request.userContext, {
          familyId,
          policyId: document.policyId,
        });
        if (deletedPolicy) {
          deletedPolicyId = document.policyId;
        }
      }
    }

    try {
      await removeStoredFile(document.storagePath);
    } catch (error) {
      request.log.warn({ error, documentId }, 'Failed to delete stored document file.');
    }

    return reply.send({
      deletedDocumentId: documentId,
      deletedPolicyId,
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
