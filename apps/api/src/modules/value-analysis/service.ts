import type { InsightLocale } from '../policies/insight';
import type { Policy } from '../policies/model';
import { OpsTaskRepository } from '../tasks/repository';
import type { UserContext } from '../../types/user-context';
import type { PolicyValueAnalysis, ValueDimension } from './model';
import { PolicyValueAnalysisRepository } from './repository';

const scoringVersion = 'v1';

const dimensionWeights: Record<ValueDimension['key'], number> = {
  coverageAdequacy: 0.3,
  affordability: 0.25,
  termsQuality: 0.2,
  waiverCompleteness: 0.15,
  renewalStability: 0.1,
};

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function scoreFromRatio(ratio: number): number {
  if (ratio <= 0.05) {
    return 92;
  }
  if (ratio <= 0.1) {
    return 82;
  }
  if (ratio <= 0.15) {
    return 70;
  }
  if (ratio <= 0.25) {
    return 55;
  }
  if (ratio <= 0.35) {
    return 40;
  }
  return 25;
}

function containsOne(text: string, items: string[]): boolean {
  return items.some((item) => text.includes(item));
}

function scoreRenewal(endDate: string | null): { score: number; reason: string } {
  if (!endDate) {
    return {
      score: 65,
      reason: '未提供到期日，续保稳定性按中性分处理。',
    };
  }

  const parsed = new Date(endDate);
  if (Number.isNaN(parsed.getTime())) {
    return {
      score: 60,
      reason: '到期日格式异常，续保稳定性按偏谨慎分处理。',
    };
  }

  const diffDays = Math.ceil((parsed.getTime() - Date.now()) / 86400000);
  if (diffDays < 0) {
    return { score: 20, reason: '保单已过期，续保稳定性较低。' };
  }
  if (diffDays <= 30) {
    return { score: 45, reason: '30天内到期，续保压力较高。' };
  }
  if (diffDays <= 90) {
    return { score: 60, reason: '90天内到期，建议提前安排续保。' };
  }
  if (diffDays <= 180) {
    return { score: 75, reason: '到期周期可控，续保稳定性中等。' };
  }
  return { score: 88, reason: '到期时间充足，续保稳定性较好。' };
}

function buildTemplateSummary(locale: InsightLocale, analysis: {
  valueScore: number;
  valueConfidence: number;
  recommendations: string[];
}): string {
  const confidence = Math.round(analysis.valueConfidence * 100);
  if (locale === 'en') {
    const action = analysis.recommendations[0] ?? 'Keep annual review cadence.';
    return `Value score ${analysis.valueScore.toFixed(1)}/100 (confidence ${confidence}%). ${action}`;
  }
  const action = analysis.recommendations[0] ?? '建议按年复盘并根据家庭变化微调保障。';
  return `性价比分 ${analysis.valueScore.toFixed(1)}/100（置信度 ${confidence}%）。${action}`;
}

function evaluatePolicy(
  policy: Policy,
  annualIncome: number,
): {
  valueScore: number;
  valueConfidence: number;
  dimensions: ValueDimension[];
  reasons: string[];
  recommendations: string[];
  needsReview: boolean;
} {
  const notes = `${policy.aiNotes ?? ''} ${policy.productName}`.toLowerCase();
  const coverageItems = policy.aiInsight?.coverageItems ?? policy.aiPayload?.coverageItems ?? [];
  const coverageCount = coverageItems.length;
  const hasSignals = Boolean(policy.aiPayload?.signals);
  const sumInsured = coverageItems
    .map((item) => Number(item.sumInsured ?? 0))
    .filter((value) => Number.isFinite(value) && value > 0)
    .reduce((sum, value) => sum + value, 0);

  let coverageScore = 50;
  if (coverageCount >= 3) {
    coverageScore += 16;
  } else if (coverageCount >= 1) {
    coverageScore += 8;
  }
  if (sumInsured >= 500000) {
    coverageScore += 18;
  } else if (sumInsured >= 200000) {
    coverageScore += 10;
  }
  if (hasSignals) {
    coverageScore += 8;
  }
  coverageScore = clamp(coverageScore, 30, 95);

  const affordabilityRatio = annualIncome > 0 ? policy.premium / annualIncome : 1;
  const affordabilityScore = scoreFromRatio(affordabilityRatio);

  let termsQuality = 72;
  if (containsOne(notes, ['免责', '除外', '既往症'])) {
    termsQuality -= 14;
  }
  if (containsOne(notes, ['等待期180', '等待期 180', '长等待期'])) {
    termsQuality -= 10;
  }
  if (containsOne(notes, ['保证续保', '0免赔', '不限社保', '质子重离子', '特药'])) {
    termsQuality += 12;
  }
  termsQuality = clamp(termsQuality, 20, 95);

  let waiverCompleteness = 45;
  if (containsOne(notes, ['豁免'])) {
    waiverCompleteness += 35;
  }
  if (containsOne(notes, ['投保人豁免', '被保险人豁免'])) {
    waiverCompleteness += 12;
  }
  waiverCompleteness = clamp(waiverCompleteness, 20, 95);

  const renewal = scoreRenewal(policy.endDate);

  const dimensions: ValueDimension[] = [
    {
      key: 'coverageAdequacy',
      weight: dimensionWeights.coverageAdequacy,
      score: coverageScore,
      reason: coverageScore >= 70 ? '保障覆盖相对完整。' : '保障覆盖与保额仍有补齐空间。',
    },
    {
      key: 'affordability',
      weight: dimensionWeights.affordability,
      score: affordabilityScore,
      reason: annualIncome > 0
        ? `年保费占基准年收入 ${(affordabilityRatio * 100).toFixed(1)}%。`
        : '缺少收入基准，负担评估精度下降。',
    },
    {
      key: 'termsQuality',
      weight: dimensionWeights.termsQuality,
      score: termsQuality,
      reason: termsQuality >= 70 ? '条款结构整体可接受。' : '条款限制项较多，建议重点复核。',
    },
    {
      key: 'waiverCompleteness',
      weight: dimensionWeights.waiverCompleteness,
      score: waiverCompleteness,
      reason: waiverCompleteness >= 70 ? '豁免条款较完整。' : '豁免责任信息不足或缺失。',
    },
    {
      key: 'renewalStability',
      weight: dimensionWeights.renewalStability,
      score: renewal.score,
      reason: renewal.reason,
    },
  ];

  const weightedTotal = dimensions.reduce((sum, item) => sum + item.weight * item.score, 0);
  const valueScore = Number(clamp(weightedTotal, 0, 100).toFixed(2));

  let confidence = 0.92;
  if (!policy.aiNotes) {
    confidence -= 0.12;
  }
  if (coverageCount === 0) {
    confidence -= 0.16;
  }
  if (!policy.endDate) {
    confidence -= 0.08;
  }
  if (!hasSignals) {
    confidence -= 0.12;
  }
  if (annualIncome <= 0) {
    confidence -= 0.2;
  }
  if (policy.premium <= 0) {
    confidence -= 0.2;
  }
  confidence = clamp(confidence, 0.35, 0.95);

  const reasons = dimensions
    .filter((item) => item.score < 65)
    .map((item) => item.reason);

  const recommendations: string[] = [];
  if (coverageScore < 65) {
    recommendations.push('建议补齐高频/高损失责任，并提升核心保额。');
  }
  if (affordabilityScore < 60) {
    recommendations.push('建议对比同类产品的保费与责任边界，优化预算分配。');
  }
  if (termsQuality < 60) {
    recommendations.push('建议重点核对免责、等待期、赔付触发条件。');
  }
  if (waiverCompleteness < 60) {
    recommendations.push('建议补充投保人/被保险人豁免条款。');
  }
  if (renewal.score < 60) {
    recommendations.push('建议提前建立续保计划，避免保障断档。');
  }
  if (recommendations.length === 0) {
    recommendations.push('当前保单性价比整体可接受，建议保持年度复盘。');
  }

  const needsReview = confidence < 0.65 || coverageCount === 0;
  return {
    valueScore,
    valueConfidence: Number(confidence.toFixed(2)),
    dimensions,
    reasons,
    recommendations,
    needsReview,
  };
}

export class PolicyValueAnalysisService {
  constructor(
    private readonly analysisRepository = new PolicyValueAnalysisRepository(),
    private readonly taskRepository = new OpsTaskRepository(),
  ) {}

  async refreshForPolicy(input: {
    ctx: UserContext;
    policy: Policy;
    annualIncome: number;
    locale: InsightLocale;
    triggerUserId: string;
  }): Promise<PolicyValueAnalysis> {
    const evaluated = evaluatePolicy(input.policy, input.annualIncome);
    const summary = buildTemplateSummary(input.locale, {
      valueScore: evaluated.valueScore,
      valueConfidence: evaluated.valueConfidence,
      recommendations: evaluated.recommendations,
    });

    const saved = await this.analysisRepository.upsert({
      tenantId: input.ctx.tenantId,
      familyId: input.policy.familyId,
      policyId: input.policy.id,
      valueScore: evaluated.valueScore,
      valueConfidence: evaluated.valueConfidence,
      dimensions: evaluated.dimensions,
      reasons: evaluated.reasons,
      recommendations: evaluated.recommendations,
      summary,
      scoringVersion,
    });

    if (evaluated.needsReview) {
      await this.taskRepository.createIfNotOpen({
        tenantId: input.ctx.tenantId,
        familyId: input.policy.familyId,
        policyId: input.policy.id,
        taskType: 'value_low_confidence',
        priority: 'high',
        title: '保单性价比结果待复核',
        description: '检测到低置信度或关键信息缺失，请人工复核并补充关键字段。',
        payload: {
          policyNo: input.policy.policyNo,
          valueConfidence: evaluated.valueConfidence,
        },
        createdByUserId: input.triggerUserId,
        dueAt: new Date(Date.now() + 2 * 86400000).toISOString(),
      });
    }

    return saved;
  }
}

