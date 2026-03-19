// Rule-based AI policy scoring and multilingual recommendation output.
import type { IncomingHttpHeaders } from 'node:http';

export type InsightLocale = 'zh' | 'en';
export type PolicyType = 'medical' | 'accident' | 'critical' | 'life' | 'vehicle' | 'other';

export interface PolicyFeatureSignals {
  sumInsured: number | null;
  hasMedicalCoverage: boolean | null;
  hasCriticalIllnessCoverage: boolean | null;
  hasSuddenDeathCoverage: boolean | null;
  hasHospitalizationAllowance: boolean | null;
  hasOutpatientCoverage: boolean | null;
}

export interface PolicyCoverageItem {
  code: string;
  name: string;
  sumInsured: number | null;
  description: string | null;
}

export interface PolicyInsightDimension {
  key: 'coverage' | 'sumInsured' | 'costPerformance';
  label: string;
  current: number;
  benchmark: number;
  comment: string;
}

export interface PolicyInsight {
  generatedAt: string;
  locale: InsightLocale;
  policyType: PolicyType;
  policyTypeLabel: string;
  protectionScore: number;
  riskScore: number;
  riskLevel: 'low' | 'medium' | 'high';
  summary: string;
  strengths: string[];
  weaknesses: string[];
  recommendations: string[];
  coverageItems: PolicyCoverageItem[];
  competitive: {
    title: string;
    subtitle: string;
    dimensions: PolicyInsightDimension[];
  };
}

export interface PolicyLikeInput {
  policyNo: string;
  insurerName: string;
  productName: string;
  premium: number;
  currency: string;
  status?: string;
  startDate: string;
  endDate: string | null;
  aiNotes?: string | null;
  signals?: Partial<PolicyFeatureSignals> | null;
  coverageItems?: PolicyCoverageItem[] | null;
}

interface PolicyBenchmark {
  type: PolicyType;
  premiumMin: number;
  premiumMax: number;
  targetSumInsured: number;
  benchmarkCoverageScore: number;
  benchmarkAmountScore: number;
  benchmarkCostScore: number;
}

type CoverageSignalKey = Exclude<keyof PolicyFeatureSignals, 'sumInsured'>;
type RuleKey =
  | 'coverage_good'
  | 'amount_good'
  | 'cost_good'
  | 'sudden_death_included'
  | 'outpatient_included'
  | 'allowance_included'
  | 'base_stable'
  | 'coverage_weak'
  | 'amount_low'
  | 'cost_low'
  | 'sudden_death_missing'
  | 'outpatient_missing'
  | 'critical_coverage_missing'
  | 'no_major_gap'
  | 'recommend_expand_scope'
  | 'recommend_raise_amount'
  | 'recommend_compare_cost'
  | 'recommend_add_sudden_death'
  | 'recommend_add_outpatient'
  | 'recommend_add_critical_core'
  | 'recommend_raise_income_replacement'
  | 'recommend_renew_soon'
  | 'recommend_keep_review';

interface EvaluatedPolicy {
  policyType: PolicyType;
  policyTypeLabelZh: string;
  policyTypeLabelEn: string;
  protectionScore: number;
  riskScore: number;
  riskLevel: 'low' | 'medium' | 'high';
  coverageScore: number;
  amountScore: number;
  costScore: number;
  strengths: RuleKey[];
  weaknesses: RuleKey[];
  recommendations: RuleKey[];
  benchmark: PolicyBenchmark;
  signals: PolicyFeatureSignals;
  coverageItems: PolicyCoverageItem[];
}

const policyBenchmarks: Record<PolicyType, PolicyBenchmark> = {
  medical: {
    type: 'medical',
    premiumMin: 300,
    premiumMax: 2500,
    targetSumInsured: 3000000,
    benchmarkCoverageScore: 82,
    benchmarkAmountScore: 80,
    benchmarkCostScore: 78,
  },
  accident: {
    type: 'accident',
    premiumMin: 100,
    premiumMax: 900,
    targetSumInsured: 500000,
    benchmarkCoverageScore: 78,
    benchmarkAmountScore: 76,
    benchmarkCostScore: 80,
  },
  critical: {
    type: 'critical',
    premiumMin: 1800,
    premiumMax: 14000,
    targetSumInsured: 500000,
    benchmarkCoverageScore: 80,
    benchmarkAmountScore: 82,
    benchmarkCostScore: 74,
  },
  life: {
    type: 'life',
    premiumMin: 800,
    premiumMax: 7000,
    targetSumInsured: 1000000,
    benchmarkCoverageScore: 77,
    benchmarkAmountScore: 84,
    benchmarkCostScore: 76,
  },
  vehicle: {
    type: 'vehicle',
    premiumMin: 2000,
    premiumMax: 9000,
    targetSumInsured: 300000,
    benchmarkCoverageScore: 75,
    benchmarkAmountScore: 72,
    benchmarkCostScore: 74,
  },
  other: {
    type: 'other',
    premiumMin: 500,
    premiumMax: 6000,
    targetSumInsured: 500000,
    benchmarkCoverageScore: 75,
    benchmarkAmountScore: 74,
    benchmarkCostScore: 74,
  },
};

const ruleTextMap: Record<RuleKey, { zh: string; en: string }> = {
  coverage_good: {
    zh: '保障责任覆盖较完整，核心风险覆盖表现较好。',
    en: 'Coverage is relatively complete for key risks.',
  },
  amount_good: {
    zh: '保额充足度较好，可承接较大风险冲击。',
    en: 'Sum insured adequacy is strong for major losses.',
  },
  cost_good: {
    zh: '保费与保障匹配度较高，性价比较好。',
    en: 'Premium and protection are balanced with good value.',
  },
  sudden_death_included: {
    zh: '已识别猝死保障，意外场景下的赔付完整度更高。',
    en: 'Sudden-death benefit is detected in this policy.',
  },
  outpatient_included: {
    zh: '已覆盖门急诊相关责任，医疗保障使用场景更完整。',
    en: 'Outpatient-related responsibilities are included.',
  },
  allowance_included: {
    zh: '住院津贴责任已覆盖，可用于住院现金流缓冲。',
    en: 'Hospitalization allowance coverage is included.',
  },
  base_stable: {
    zh: '保障结构整体稳定，建议按年复盘责任变化。',
    en: 'Protection structure is stable; review annually.',
  },
  coverage_weak: {
    zh: '保障责任存在明显缺口，需优先补齐核心责任。',
    en: 'Coverage has notable gaps and needs reinforcement.',
  },
  amount_low: {
    zh: '保额偏低，可能不足以覆盖重大损失场景。',
    en: 'Sum insured may be insufficient for major expenses.',
  },
  cost_low: {
    zh: '当前保费与保障匹配度偏低，性价比一般。',
    en: 'Price-to-protection ratio appears weak.',
  },
  sudden_death_missing: {
    zh: '未识别到猝死责任，意外险保障完整性偏弱。',
    en: 'Sudden-death benefit was not detected.',
  },
  outpatient_missing: {
    zh: '未识别门急诊责任，医疗险日常就医保障可能不足。',
    en: 'Outpatient coverage was not detected.',
  },
  critical_coverage_missing: {
    zh: '重疾核心责任识别不足，需核对重疾给付条款。',
    en: 'Core critical illness coverage appears insufficient.',
  },
  no_major_gap: {
    zh: '未识别重大短板，可继续优化条款细节。',
    en: 'No major weakness detected; refine by terms.',
  },
  recommend_expand_scope: {
    zh: '建议补充缺失责任（如门急诊、住院津贴、特药等），提升保障完整度。',
    en: 'Expand missing responsibilities to improve coverage completeness.',
  },
  recommend_raise_amount: {
    zh: '建议提升保额或增加补充险，提高重大支出承受能力。',
    en: 'Increase sum insured or add supplemental coverage.',
  },
  recommend_compare_cost: {
    zh: '建议对比同类产品保费、免赔额和免责条款，优化性价比。',
    en: 'Compare peer products, deductibles, and exclusions for better value.',
  },
  recommend_add_sudden_death: {
    zh: '若为意外险，建议优先选择含猝死责任的方案并核对等待期。',
    en: 'For accident policies, prioritize plans with sudden-death coverage.',
  },
  recommend_add_outpatient: {
    zh: '医疗险建议补充门急诊保障，提升高频就医场景覆盖。',
    en: 'Add outpatient coverage for high-frequency medical usage.',
  },
  recommend_add_critical_core: {
    zh: '重疾险建议优先核对重疾定义、轻中症赔付和二次赔付责任。',
    en: 'For critical illness plans, verify core definitions and payout terms.',
  },
  recommend_raise_income_replacement: {
    zh: '寿险保额建议覆盖家庭 3-5 年支出与主要负债，保障收入替代。',
    en: 'Increase life coverage to better support income replacement.',
  },
  recommend_renew_soon: {
    zh: '保单将于 30 天内到期，建议提前完成续保并复核责任变化。',
    en: 'Policy expires within 30 days; renew early and review terms.',
  },
  recommend_keep_review: {
    zh: '建议每年结合家庭成员变化、医疗成本和负债情况复盘一次。',
    en: 'Review yearly with family, medical-cost, and liability changes.',
  },
};

// Resolve response language from headers so AI copy follows current UI locale.
export function resolveInsightLocale(
  headers?: IncomingHttpHeaders | Record<string, unknown>,
): InsightLocale {
  if (!headers) {
    return 'zh';
  }

  const rawLang = headers['x-lang'] ?? headers['accept-language'];
  const lang = Array.isArray(rawLang) ? rawLang[0] : rawLang;
  if (!lang) {
    return 'zh';
  }

  const value = String(lang).toLowerCase();
  return value.startsWith('en') ? 'en' : 'zh';
}

// Normalize policy signals to keep scoring deterministic across import/create flows.
export function normalizeSignals(
  signals?: Partial<PolicyFeatureSignals> | null,
): PolicyFeatureSignals {
  return {
    sumInsured: normalizeNullableNumber(signals?.sumInsured),
    hasMedicalCoverage: normalizeNullableBoolean(signals?.hasMedicalCoverage),
    hasCriticalIllnessCoverage: normalizeNullableBoolean(signals?.hasCriticalIllnessCoverage),
    hasSuddenDeathCoverage: normalizeNullableBoolean(signals?.hasSuddenDeathCoverage),
    hasHospitalizationAllowance: normalizeNullableBoolean(signals?.hasHospitalizationAllowance),
    hasOutpatientCoverage: normalizeNullableBoolean(signals?.hasOutpatientCoverage),
  };
}

// Merge external AI signals over heuristic signals when both are present.
export function mergeSignals(
  base?: Partial<PolicyFeatureSignals> | null,
  override?: Partial<PolicyFeatureSignals> | null,
): PolicyFeatureSignals {
  const left = normalizeSignals(base);
  const right = normalizeSignals(override);

  return {
    sumInsured: right.sumInsured ?? left.sumInsured,
    hasMedicalCoverage: right.hasMedicalCoverage ?? left.hasMedicalCoverage,
    hasCriticalIllnessCoverage: right.hasCriticalIllnessCoverage ?? left.hasCriticalIllnessCoverage,
    hasSuddenDeathCoverage: right.hasSuddenDeathCoverage ?? left.hasSuddenDeathCoverage,
    hasHospitalizationAllowance: right.hasHospitalizationAllowance ?? left.hasHospitalizationAllowance,
    hasOutpatientCoverage: right.hasOutpatientCoverage ?? left.hasOutpatientCoverage,
  };
}

// Parse OCR text into structured coverage signals used by the AI scorer.
export function extractPolicySignalsFromText(text: string): PolicyFeatureSignals {
  const normalized = normalizeText(text);
  return {
    sumInsured: extractSumInsured(normalized),
    hasMedicalCoverage: detectKeywordPresence(normalized, ['住院医疗', '医疗费用', '医疗责任', '住院报销', 'medical']),
    hasCriticalIllnessCoverage: detectKeywordPresence(normalized, ['重大疾病', '重疾', 'critical illness']),
    hasSuddenDeathCoverage: detectSuddenDeathCoverage(normalized),
    hasHospitalizationAllowance: detectKeywordPresence(normalized, ['住院津贴', '每日津贴', 'hospital allowance']),
    hasOutpatientCoverage: detectKeywordPresence(normalized, ['门急诊', '门诊', 'outpatient']),
  };
}

export function inferPolicyType(productName: string, insurerName = '', notes = ''): PolicyType {
  const text = normalizeText(`${productName} ${insurerName} ${notes}`);

  if (containsOne(text, ['医疗', '百万医疗', '门急诊', '住院医疗', 'medical'])) {
    return 'medical';
  }
  if (containsOne(text, ['意外', '驾乘', '交通意外', 'accident'])) {
    return 'accident';
  }
  if (containsOne(text, ['重疾', '重大疾病', '防癌', 'critical illness'])) {
    return 'critical';
  }
  if (containsOne(text, ['寿险', '身故', '定期寿险', 'life'])) {
    return 'life';
  }
  if (containsOne(text, ['车险', '交强', '商业险', '机动车'])) {
    return 'vehicle';
  }
  return 'other';
}

// Build AI risk score, recommendation text, and chart-ready benchmarking payload.
export function buildPolicyAiOutput(input: PolicyLikeInput, locale: InsightLocale): {
  aiRiskScore: number;
  aiNotes: string;
  aiInsight: PolicyInsight;
} {
  const evaluation = evaluatePolicy(input);
  const aiInsight = localizeInsight(evaluation, locale);
  const aiNotes = composeAiNotes(aiInsight);

  return {
    aiRiskScore: aiInsight.riskScore,
    aiNotes,
    aiInsight,
  };
}

function evaluatePolicy(input: PolicyLikeInput): EvaluatedPolicy {
  const policyType = inferPolicyType(input.productName, input.insurerName, input.aiNotes ?? '');
  const benchmark = policyBenchmarks[policyType];
  const signals = normalizeSignals(input.signals);
  const coverageItems = normalizeCoverageItems(input.coverageItems, signals, policyType);

  const coverageScore = scoreCoverage(policyType, signals);
  const amountScore = scoreSumInsured(signals.sumInsured, benchmark.targetSumInsured);
  const costScore = scoreCost(input.premium, benchmark.premiumMin, benchmark.premiumMax);
  const expiryAdjust = scoreExpiryAdjust(input.endDate);

  const protectionScore = roundToInt(
    clamp(coverageScore * 0.42 + amountScore * 0.33 + costScore * 0.25 + expiryAdjust, 0, 100),
  );
  const riskScore = 100 - protectionScore;
  const riskLevel: 'low' | 'medium' | 'high' = riskScore >= 60 ? 'high' : riskScore >= 36 ? 'medium' : 'low';

  const strengths = evaluateStrengths(policyType, coverageScore, amountScore, costScore, signals);
  const weaknesses = evaluateWeaknesses(policyType, coverageScore, amountScore, costScore, signals);
  const recommendations = evaluateRecommendations(
    policyType,
    coverageScore,
    amountScore,
    costScore,
    input.endDate,
    signals,
    benchmark.targetSumInsured,
  );

  return {
    policyType,
    policyTypeLabelZh: policyTypeLabel(policyType, 'zh'),
    policyTypeLabelEn: policyTypeLabel(policyType, 'en'),
    protectionScore,
    riskScore,
    riskLevel,
    coverageScore,
    amountScore,
    costScore,
    strengths,
    weaknesses,
    recommendations,
    benchmark,
    signals,
    coverageItems,
  };
}

function localizeInsight(evaluation: EvaluatedPolicy, locale: InsightLocale): PolicyInsight {
  const summary = locale === 'zh'
    ? `保障评分 ${evaluation.protectionScore}/100，风险评分 ${evaluation.riskScore}/100（${riskLevelText(evaluation.riskLevel, locale)}）。`
    : `Protection score ${evaluation.protectionScore}/100, risk score ${evaluation.riskScore}/100 (${riskLevelText(evaluation.riskLevel, locale)}).`;

  const strengths = evaluation.strengths.map((item) => localizeRuleText(item, locale));
  const weaknesses = evaluation.weaknesses.map((item) => localizeRuleText(item, locale));
  const recommendations = evaluation.recommendations.map((item) => localizeRuleText(item, locale));
  const coverageItems = evaluation.coverageItems.map((item) => ({
    ...item,
    name: localizeCoverageName(item.code, item.name, locale),
  }));

  return {
    generatedAt: new Date().toISOString(),
    locale,
    policyType: evaluation.policyType,
    policyTypeLabel: locale === 'zh' ? evaluation.policyTypeLabelZh : evaluation.policyTypeLabelEn,
    protectionScore: evaluation.protectionScore,
    riskScore: evaluation.riskScore,
    riskLevel: evaluation.riskLevel,
    summary,
    strengths,
    weaknesses,
    recommendations,
    coverageItems,
    competitive: {
      title: t(locale, '同类产品对比', 'Peer Comparison'),
      subtitle: t(
        locale,
        '基于同险种常见责任与价格区间的规则化对比（非实时报价）。',
        'Rule-based benchmark for this policy type (not a real-time quote).',
      ),
      dimensions: buildCompetitiveDimensions(evaluation, locale),
    },
  };
}

function buildCompetitiveDimensions(evaluation: EvaluatedPolicy, locale: InsightLocale): PolicyInsightDimension[] {
  const labels = buildDimensionLabels(evaluation.policyType, locale);
  return [
    {
      key: 'coverage',
      label: labels.coverage,
      current: evaluation.coverageScore,
      benchmark: evaluation.benchmark.benchmarkCoverageScore,
      comment: buildDimensionComment(locale, 'coverage', evaluation),
    },
    {
      key: 'sumInsured',
      label: labels.sumInsured,
      current: evaluation.amountScore,
      benchmark: evaluation.benchmark.benchmarkAmountScore,
      comment: buildDimensionComment(locale, 'sumInsured', evaluation),
    },
    {
      key: 'costPerformance',
      label: labels.costPerformance,
      current: evaluation.costScore,
      benchmark: evaluation.benchmark.benchmarkCostScore,
      comment: buildDimensionComment(locale, 'costPerformance', evaluation),
    },
  ];
}

function buildDimensionLabels(
  type: PolicyType,
  locale: InsightLocale,
): Record<PolicyInsightDimension['key'], string> {
  switch (type) {
    case 'medical':
      return {
        coverage: t(locale, '医疗责任覆盖度', 'Medical Coverage'),
        sumInsured: t(locale, '医疗保额充足度', 'Medical Sum Insured'),
        costPerformance: t(locale, '保费性价比', 'Cost Performance'),
      };
    case 'accident':
      return {
        coverage: t(locale, '意外责任覆盖度', 'Accident Coverage'),
        sumInsured: t(locale, '意外保额竞争力', 'Accident Sum Insured'),
        costPerformance: t(locale, '保费性价比', 'Cost Performance'),
      };
    case 'critical':
      return {
        coverage: t(locale, '重疾责任完整度', 'Critical Coverage'),
        sumInsured: t(locale, '重疾保额充足度', 'Critical Sum Insured'),
        costPerformance: t(locale, '保费性价比', 'Cost Performance'),
      };
    case 'life':
      return {
        coverage: t(locale, '身故/全残责任覆盖', 'Life Coverage'),
        sumInsured: t(locale, '收入替代保额', 'Income Replacement Amount'),
        costPerformance: t(locale, '保费性价比', 'Cost Performance'),
      };
    case 'vehicle':
      return {
        coverage: t(locale, '车险责任范围', 'Vehicle Coverage'),
        sumInsured: t(locale, '责任限额充足度', 'Liability Limit Adequacy'),
        costPerformance: t(locale, '保费性价比', 'Cost Performance'),
      };
    case 'other':
      return {
        coverage: t(locale, '保障覆盖度', 'Coverage'),
        sumInsured: t(locale, '保额充足度', 'Sum Insured'),
        costPerformance: t(locale, '保费性价比', 'Cost Performance'),
      };
  }
}

function normalizeCoverageItems(
  items: PolicyCoverageItem[] | null | undefined,
  signals: PolicyFeatureSignals,
  policyType: PolicyType,
): PolicyCoverageItem[] {
  const normalized = (items ?? [])
    .filter((item) => item && typeof item === 'object')
    .map((item) => ({
      code: String(item.code || '').trim().toLowerCase(),
      name: String(item.name || '').trim(),
      sumInsured: normalizeNullableNumber(item.sumInsured),
      description: item.description ? String(item.description).trim() : null,
    }))
    .filter((item) => item.name.length > 0)
    .slice(0, 24);

  const mergedByCode = new Map<string, PolicyCoverageItem>();
  for (const item of normalized) {
    const key = item.code || normalizeText(item.name).replace(/[^\p{L}\p{N}]+/gu, '_').slice(0, 40);
    if (!key) {
      continue;
    }
    const existing = mergedByCode.get(key);
    if (!existing) {
      mergedByCode.set(key, { ...item, code: key });
      continue;
    }
    mergedByCode.set(key, {
      ...existing,
      sumInsured: existing.sumInsured ?? item.sumInsured,
      description: existing.description ?? item.description,
    });
  }

  const merged = Array.from(mergedByCode.values());
  if (merged.length > 0) {
    return merged;
  }

  return buildFallbackCoverageItems(policyType, signals);
}

function buildFallbackCoverageItems(
  policyType: PolicyType,
  signals: PolicyFeatureSignals,
): PolicyCoverageItem[] {
  const items: PolicyCoverageItem[] = [];
  if (signals.sumInsured !== null) {
    items.push({
      code: 'core_sum_insured',
      name: policyType === 'life' ? '身故保险金' : '基础保额',
      sumInsured: signals.sumInsured,
      description: null,
    });
  }
  if (signals.hasMedicalCoverage === true) {
    items.push({
      code: 'medical_coverage',
      name: '住院医疗责任',
      sumInsured: signals.sumInsured,
      description: null,
    });
  }
  if (signals.hasOutpatientCoverage === true) {
    items.push({
      code: 'outpatient_coverage',
      name: '门急诊责任',
      sumInsured: null,
      description: null,
    });
  }
  if (signals.hasHospitalizationAllowance === true) {
    items.push({
      code: 'hospital_allowance',
      name: '住院津贴责任',
      sumInsured: null,
      description: null,
    });
  }
  if (signals.hasCriticalIllnessCoverage === true) {
    items.push({
      code: 'critical_coverage',
      name: '重大疾病责任',
      sumInsured: signals.sumInsured,
      description: null,
    });
  }
  if (signals.hasSuddenDeathCoverage === true) {
    items.push({
      code: 'sudden_death_coverage',
      name: '猝死责任',
      sumInsured: signals.sumInsured,
      description: null,
    });
  }
  return items.slice(0, 8);
}

function localizeCoverageName(code: string, fallbackName: string, locale: InsightLocale): string {
  if (locale === 'zh') {
    return fallbackName;
  }
  const map: Record<string, string> = {
    core_sum_insured: 'Core Sum Insured',
    medical_coverage: 'Hospital Medical Coverage',
    outpatient_coverage: 'Outpatient Coverage',
    hospital_allowance: 'Hospital Allowance',
    critical_coverage: 'Critical Illness Coverage',
    sudden_death_coverage: 'Sudden Death Coverage',
  };
  return map[code] ?? fallbackName;
}

function composeAiNotes(insight: PolicyInsight): string {
  const lines = [
    insight.summary,
    ...insight.recommendations.map((item) => `- ${item}`),
  ];
  return lines.join('\n');
}

function scoreCoverage(type: PolicyType, signals: PolicyFeatureSignals): number {
  const weights = getCoverageWeights(type);
  const totalWeight = weights.reduce((sum, item) => sum + item.weight, 0);
  if (totalWeight <= 0) {
    return 60;
  }

  let weighted = 0;
  for (const item of weights) {
    const value = signals[item.key];
    weighted += toSignalScore(value) * item.weight;
  }
  return roundToInt((weighted / totalWeight) * 100);
}

function getCoverageWeights(type: PolicyType): Array<{ key: CoverageSignalKey; weight: number }> {
  switch (type) {
    case 'medical':
      return [
        { key: 'hasMedicalCoverage', weight: 4 },
        { key: 'hasOutpatientCoverage', weight: 2 },
        { key: 'hasHospitalizationAllowance', weight: 1 },
      ];
    case 'accident':
      return [
        { key: 'hasMedicalCoverage', weight: 2 },
        { key: 'hasSuddenDeathCoverage', weight: 3 },
        { key: 'hasHospitalizationAllowance', weight: 1 },
      ];
    case 'critical':
      return [
        { key: 'hasCriticalIllnessCoverage', weight: 4 },
        { key: 'hasMedicalCoverage', weight: 1 },
      ];
    case 'life':
      return [
        { key: 'hasSuddenDeathCoverage', weight: 3 },
        { key: 'hasMedicalCoverage', weight: 1 },
      ];
    case 'vehicle':
      return [
        { key: 'hasMedicalCoverage', weight: 2 },
        { key: 'hasHospitalizationAllowance', weight: 1 },
      ];
    case 'other':
      return [
        { key: 'hasMedicalCoverage', weight: 1 },
        { key: 'hasCriticalIllnessCoverage', weight: 1 },
        { key: 'hasSuddenDeathCoverage', weight: 1 },
      ];
  }
}

function scoreSumInsured(sumInsured: number | null, target: number): number {
  if (sumInsured === null || sumInsured <= 0) {
    return 52;
  }

  const ratio = sumInsured / target;
  const baseline = 42 + clamp(ratio, 0, 1.7) * 36;
  const adjusted = ratio < 0.4 ? baseline - 8 : baseline;
  return roundToInt(clamp(adjusted, 20, 100));
}

function scoreCost(premium: number, min: number, max: number): number {
  if (!Number.isFinite(premium) || premium <= 0) {
    return 35;
  }

  const center = (min + max) / 2;
  if (premium >= min && premium <= max) {
    const distance = Math.abs(premium - center);
    const maxDistance = (max - min) / 2;
    const closeness = 1 - distance / Math.max(1, maxDistance);
    return roundToInt(clamp(72 + closeness * 18, 60, 92));
  }

  if (premium < min) {
    return roundToInt(clamp(68 + (premium / Math.max(1, min)) * 10, 55, 80));
  }

  const overRate = (premium - max) / Math.max(1, max);
  return roundToInt(clamp(78 - overRate * 35, 30, 78));
}

function scoreExpiryAdjust(endDate: string | null): number {
  if (!endDate) {
    return 0;
  }

  const parsed = parseDate(endDate);
  if (!parsed) {
    return 0;
  }

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diffDays = Math.ceil((parsed.getTime() - today.getTime()) / 86400000);

  if (diffDays < 0) {
    return -20;
  }
  if (diffDays <= 30) {
    return -15;
  }
  if (diffDays <= 90) {
    return -8;
  }
  return 0;
}

function evaluateStrengths(
  type: PolicyType,
  coverageScore: number,
  amountScore: number,
  costScore: number,
  signals: PolicyFeatureSignals,
): RuleKey[] {
  const items: RuleKey[] = [];
  if (coverageScore >= 78) {
    items.push('coverage_good');
  }
  if (amountScore >= 76) {
    items.push('amount_good');
  }
  if (costScore >= 78) {
    items.push('cost_good');
  }
  if (type === 'accident' && signals.hasSuddenDeathCoverage === true) {
    items.push('sudden_death_included');
  }
  if (type === 'medical' && signals.hasOutpatientCoverage === true) {
    items.push('outpatient_included');
  }
  if (type === 'medical' && signals.hasHospitalizationAllowance === true) {
    items.push('allowance_included');
  }
  if (items.length === 0) {
    items.push('base_stable');
  }
  return items;
}

function evaluateWeaknesses(
  type: PolicyType,
  coverageScore: number,
  amountScore: number,
  costScore: number,
  signals: PolicyFeatureSignals,
): RuleKey[] {
  const items: RuleKey[] = [];
  if (coverageScore < 60) {
    items.push('coverage_weak');
  }
  if (amountScore < 60) {
    items.push('amount_low');
  }
  if (costScore < 58) {
    items.push('cost_low');
  }
  if (type === 'accident' && signals.hasSuddenDeathCoverage !== true) {
    items.push('sudden_death_missing');
  }
  if (type === 'medical' && signals.hasOutpatientCoverage !== true) {
    items.push('outpatient_missing');
  }
  if (type === 'critical' && signals.hasCriticalIllnessCoverage !== true) {
    items.push('critical_coverage_missing');
  }
  if (items.length === 0) {
    items.push('no_major_gap');
  }
  return items;
}

function evaluateRecommendations(
  type: PolicyType,
  coverageScore: number,
  amountScore: number,
  costScore: number,
  endDate: string | null,
  signals: PolicyFeatureSignals,
  targetSumInsured: number,
): RuleKey[] {
  const items: RuleKey[] = [];

  if (coverageScore < 62) {
    items.push('recommend_expand_scope');
  }
  if (amountScore < 60) {
    items.push('recommend_raise_amount');
  }
  if (costScore < 58) {
    items.push('recommend_compare_cost');
  }
  if (type === 'accident' && signals.hasSuddenDeathCoverage !== true) {
    items.push('recommend_add_sudden_death');
  }
  if (type === 'medical' && signals.hasOutpatientCoverage !== true) {
    items.push('recommend_add_outpatient');
  }
  if (type === 'critical' && signals.hasCriticalIllnessCoverage !== true) {
    items.push('recommend_add_critical_core');
  }
  if (type === 'life' && signals.sumInsured !== null && signals.sumInsured < targetSumInsured * 0.6) {
    items.push('recommend_raise_income_replacement');
  }

  const parsed = endDate ? parseDate(endDate) : null;
  if (parsed) {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const diffDays = Math.ceil((parsed.getTime() - today.getTime()) / 86400000);
    if (diffDays >= 0 && diffDays <= 30) {
      items.push('recommend_renew_soon');
    }
  }

  if (items.length === 0) {
    items.push('recommend_keep_review');
  }

  return Array.from(new Set(items)).slice(0, 6);
}

function buildDimensionComment(
  locale: InsightLocale,
  key: PolicyInsightDimension['key'],
  evaluation: EvaluatedPolicy,
): string {
  const score = key === 'coverage'
    ? evaluation.coverageScore
    : key === 'sumInsured'
        ? evaluation.amountScore
        : evaluation.costScore;
  const tier = score >= 78 ? 'good' : score >= 60 ? 'medium' : 'weak';

  if (key === 'coverage') {
    if (evaluation.policyType === 'accident' && evaluation.signals.hasSuddenDeathCoverage !== true) {
      return t(
        locale,
        '意外责任识别中未发现猝死保障，建议优先补齐该责任。',
        'Sudden-death coverage was not detected in accident responsibilities.',
      );
    }
    if (evaluation.policyType === 'medical' && evaluation.signals.hasOutpatientCoverage !== true) {
      return t(
        locale,
        '医疗责任中门急诊保障识别偏弱，日常就医覆盖可能不足。',
        'Outpatient coverage appears weak in medical responsibilities.',
      );
    }
    if (tier === 'good') {
      return t(locale, '保障责任覆盖较完整，核心场景匹配度较好。', 'Coverage scope is relatively complete.');
    }
    if (tier === 'medium') {
      return t(locale, '保障责任中等，建议补齐高频或高损失场景。', 'Coverage is moderate; fill high-frequency gaps.');
    }
    return t(locale, '保障责任偏弱，需优先补齐核心责任。', 'Coverage is weak and needs reinforcement.');
  }

  if (key === 'sumInsured') {
    if (tier === 'good') {
      return t(locale, '保额相对同类方案更充足，抗风险缓冲较好。', 'Sum insured is competitive for this type.');
    }
    if (tier === 'medium') {
      return t(locale, '保额基本可用，但面对重大支出缓冲有限。', 'Sum insured is acceptable but buffer is limited.');
    }
    return t(locale, '保额偏低，建议提升保额或补充同类保障。', 'Sum insured may be too low for large losses.');
  }

  if (tier === 'good') {
    return t(locale, '保费与保障匹配度较高，性价比较好。', 'Price-to-coverage ratio is strong.');
  }
  if (tier === 'medium') {
    return t(locale, '性价比中等，建议对比同类产品的免责和赔付条件。', 'Cost performance is average; compare alternatives.');
  }
  return t(locale, '性价比偏弱，建议重新评估保费与责任匹配。', 'Cost performance is weak; reevaluate this policy.');
}

function localizeRuleText(rule: RuleKey, locale: InsightLocale): string {
  const item = ruleTextMap[rule];
  return locale === 'zh' ? item.zh : item.en;
}

function policyTypeLabel(type: PolicyType, locale: InsightLocale): string {
  const map: Record<PolicyType, { zh: string; en: string }> = {
    medical: { zh: '医疗险', en: 'Medical Insurance' },
    accident: { zh: '意外险', en: 'Accident Insurance' },
    critical: { zh: '重疾险', en: 'Critical Illness Insurance' },
    life: { zh: '寿险', en: 'Life Insurance' },
    vehicle: { zh: '车险', en: 'Vehicle Insurance' },
    other: { zh: '综合险', en: 'General Insurance' },
  };
  return locale === 'zh' ? map[type].zh : map[type].en;
}

function toSignalScore(value: boolean | null): number {
  if (value === true) {
    return 1;
  }
  if (value === false) {
    return 0.3;
  }
  return 0.55;
}

function normalizeText(text: string): string {
  return text
    .normalize('NFKC')
    .replace(/\r/g, '\n')
    .replace(/\t/g, ' ')
    .replace(/[ ]{2,}/g, ' ')
    .toLowerCase();
}

function extractSumInsured(text: string): number | null {
  const patterns = [
    /(?:保险金额|基本保险金额|责任限额|保额|sum insured|coverage amount)\s*[:：]?\s*(?:人民币|rmb|cny|¥|￥)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(万)?/i,
    /(?:身故保险金|重大疾病保险金)\s*[:：]?\s*(?:人民币|rmb|cny|¥|￥)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(万)?/i,
  ];

  for (const pattern of patterns) {
    const match = pattern.exec(text);
    if (!match) {
      continue;
    }
    const numeric = Number(match[1].replace(/,/g, ''));
    if (!Number.isFinite(numeric) || numeric <= 0) {
      continue;
    }
    const multiplier = match[2] ? 10000 : 1;
    return numeric * multiplier;
  }
  return null;
}

function detectSuddenDeathCoverage(text: string): boolean | null {
  if (!containsOne(text, ['猝死', 'sudden death'])) {
    return null;
  }
  const negativePatterns = ['猝死不赔', '猝死除外', '猝死免责', '不承担猝死'];
  if (negativePatterns.some((item) => text.includes(item))) {
    return false;
  }
  return true;
}

function detectKeywordPresence(text: string, keywords: string[]): boolean | null {
  return keywords.some((item) => text.includes(item.toLowerCase())) ? true : null;
}

function containsOne(text: string, keywords: string[]): boolean {
  return keywords.some((item) => text.includes(item.toLowerCase()));
}

function parseDate(value: string): Date | null {
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function normalizeNullableBoolean(value: unknown): boolean | null {
  return typeof value === 'boolean' ? value : null;
}

function normalizeNullableNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value) && value > 0) {
    return value;
  }
  return null;
}

function riskLevelText(level: EvaluatedPolicy['riskLevel'], locale: InsightLocale): string {
  if (locale === 'zh') {
    if (level === 'high') {
      return '高风险';
    }
    if (level === 'medium') {
      return '中风险';
    }
    return '低风险';
  }
  if (level === 'high') {
    return 'high risk';
  }
  if (level === 'medium') {
    return 'medium risk';
  }
  return 'low risk';
}

function t(locale: InsightLocale, zh: string, en: string): string {
  return locale === 'zh' ? zh : en;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function roundToInt(value: number): number {
  return Math.round(value);
}
