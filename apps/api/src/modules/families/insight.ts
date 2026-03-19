// Household-level AI analysis for member priorities and policy gaps.
import type { FamilyMember } from './model';
import type { Policy } from '../policies/model';
import { inferPolicyType, type InsightLocale } from '../policies/insight';

type MemberRoleType = 'breadwinner' | 'child' | 'senior' | 'adult';
type PriorityLevel = 'high' | 'medium' | 'low';

export interface FamilySourceReference {
  title: string;
  url: string;
  note: string;
}

export interface MemberRecommendation {
  insuranceType: string;
  priority: PriorityLevel;
  reason: string;
}

export interface FamilyMemberInsight {
  memberId: string;
  name: string;
  relation: string;
  age: number | null;
  roleType: MemberRoleType;
  score: number;
  focusPoints: string[];
  painPoints: string[];
  recommendations: MemberRecommendation[];
}

export interface FamilyPolicyGap {
  title: string;
  severity: PriorityLevel;
  description: string;
}

export interface FamilyInsight {
  familyId: string;
  locale: InsightLocale;
  generatedAt: string;
  householdScore: number;
  riskLevel: 'low' | 'medium' | 'high';
  summary: string;
  policyCoverage: {
    medical: boolean;
    accident: boolean;
    critical: boolean;
    life: boolean;
  };
  gaps: FamilyPolicyGap[];
  members: FamilyMemberInsight[];
  priorities: string[];
  sources: FamilySourceReference[];
}

interface BuildFamilyInsightInput {
  familyId: string;
  locale: InsightLocale;
  members: FamilyMember[];
  policies: Policy[];
}

interface SourceSeed {
  titleZh: string;
  titleEn: string;
  noteZh: string;
  noteEn: string;
  url: string;
}

const sourceSeeds: SourceSeed[] = [
  {
    titleZh: '穗岁康（广州市政府）',
    titleEn: 'Suisuikang (Guangzhou Government)',
    noteZh: '官方页面提供参保入口与年度政策说明。',
    noteEn: 'Official enrollment and annual policy details.',
    url: 'https://www.gz.gov.cn/zt/sskjkzl/content/post_10612873.html',
  },
  {
    titleZh: '穗岁康专题（广州市医保局）',
    titleEn: 'Suisuikang Topic (Guangzhou Healthcare Security Bureau)',
    noteZh: '可查询保障责任、投保规则与常见问题。',
    noteEn: 'Coverage rules and FAQ for the program.',
    url: 'https://ybj.gz.gov.cn/ztzl/ssk/',
  },
  {
    titleZh: '国家医保局：长期护理保险试点进展',
    titleEn: 'NHSA: Long-term Care Insurance Pilot',
    noteZh: '长护险试点覆盖与待遇信息，适合老年成员规划参考。',
    noteEn: 'Pilot coverage and benefits for long-term care planning.',
    url: 'https://www.nhsa.gov.cn/art/2024/7/25/art_7_13195.html',
  },
  {
    titleZh: '国务院办公厅：商业健康保险高质量发展意见',
    titleEn: 'General Office of the State Council: Commercial Health Insurance Guidance',
    noteZh: '强调多层次医疗保障体系建设方向。',
    noteEn: 'Policy direction for multi-layer healthcare protection.',
    url: 'https://www.gov.cn/zhengce/content/202408/content_6967835.htm',
  },
];

export function buildFamilyInsight(input: BuildFamilyInsightInput): FamilyInsight {
  const coverage = analyzeCoverage(input.policies);
  const members = input.members.map((member) => analyzeMember(input.locale, member, coverage));
  const householdScore = calculateHouseholdScore(members, coverage);
  const riskLevel: 'low' | 'medium' | 'high' = householdScore >= 75 ? 'low' : householdScore >= 55 ? 'medium' : 'high';

  const gaps = evaluateFamilyGaps(input.locale, coverage, input.policies);
  const priorities = buildFamilyPriorities(input.locale, members, gaps);
  const summary = buildSummary(input.locale, householdScore, members.length, gaps.length);

  return {
    familyId: input.familyId,
    locale: input.locale,
    generatedAt: new Date().toISOString(),
    householdScore,
    riskLevel,
    summary,
    policyCoverage: coverage,
    gaps,
    members,
    priorities,
    sources: buildSourceReferences(input.locale),
  };
}

function analyzeCoverage(policies: Policy[]): FamilyInsight['policyCoverage'] {
  const types = new Set(
    policies.map((policy) => inferPolicyType(policy.productName, policy.insurerName, policy.aiNotes ?? '')),
  );
  return {
    medical: types.has('medical'),
    accident: types.has('accident'),
    critical: types.has('critical'),
    life: types.has('life'),
  };
}

function analyzeMember(
  locale: InsightLocale,
  member: FamilyMember,
  coverage: FamilyInsight['policyCoverage'],
): FamilyMemberInsight {
  const age = calculateAge(member.birthDate);
  const roleType = resolveRoleType(member.relation, age);
  const focusPoints = buildFocusPoints(locale, roleType);
  const painPoints = buildPainPoints(locale, roleType, coverage);
  const recommendations = buildMemberRecommendations(locale, roleType, coverage);
  const score = calculateMemberScore(roleType, coverage);

  return {
    memberId: member.id,
    name: member.name,
    relation: member.relation,
    age,
    roleType,
    score,
    focusPoints,
    painPoints,
    recommendations,
  };
}

function calculateHouseholdScore(
  members: FamilyMemberInsight[],
  coverage: FamilyInsight['policyCoverage'],
): number {
  if (members.length === 0) {
    return 40;
  }

  // Breadwinner members have higher weight in household protection scoring.
  let weightedSum = 0;
  let totalWeight = 0;
  for (const member of members) {
    const weight = member.roleType === 'breadwinner' ? 1.25 : member.roleType === 'senior' ? 1.1 : 1;
    weightedSum += member.score * weight;
    totalWeight += weight;
  }
  const memberAverage = totalWeight > 0 ? weightedSum / totalWeight : 50;

  const policyBreadth = [coverage.medical, coverage.accident, coverage.critical, coverage.life].filter(Boolean).length;
  const policyScore = policyBreadth * 25;

  return roundToInt(clamp(memberAverage * 0.65 + policyScore * 0.35, 0, 100));
}

function evaluateFamilyGaps(
  locale: InsightLocale,
  coverage: FamilyInsight['policyCoverage'],
  policies: Policy[],
): FamilyPolicyGap[] {
  const gaps: FamilyPolicyGap[] = [];

  if (!coverage.life) {
    gaps.push({
      title: t(locale, '家庭收入替代保障缺口', 'Income protection gap'),
      severity: 'high',
      description: t(
        locale,
        '未识别寿险配置，家庭经济支柱发生风险时收入替代能力不足。',
        'No life insurance detected for household income replacement.',
      ),
    });
  }

  if (!coverage.critical) {
    gaps.push({
      title: t(locale, '重大疾病保障不足', 'Critical illness gap'),
      severity: 'high',
      description: t(
        locale,
        '未识别重疾险配置，重大疾病可能引发较大现金流压力。',
        'Critical illness coverage is missing and may stress cashflow.',
      ),
    });
  }

  if (!coverage.medical) {
    gaps.push({
      title: t(locale, '医疗报销保障不足', 'Medical reimbursement gap'),
      severity: 'high',
      description: t(
        locale,
        '未识别医疗险配置，住院与特药支出风险较高。',
        'Medical reimbursement coverage is missing.',
      ),
    });
  }

  if (!coverage.accident) {
    gaps.push({
      title: t(locale, '意外保障不足', 'Accident gap'),
      severity: 'medium',
      description: t(locale, '未识别意外险配置，突发意外缓冲不足。', 'Accident protection is missing.'),
    });
  }

  const expiringSoon = policies.filter((policy) => isExpiringSoon(policy.endDate)).length;
  if (expiringSoon > 0) {
    gaps.push({
      title: t(locale, '30天内续保压力', 'Renewal pressure'),
      severity: 'medium',
      description: t(
        locale,
        `有 ${expiringSoon} 份保单将在 30 天内到期，建议优先处理续保衔接。`,
        `${expiringSoon} policies expire within 30 days; prioritize renewals.`,
      ),
    });
  }

  return gaps;
}

function buildFamilyPriorities(
  locale: InsightLocale,
  members: FamilyMemberInsight[],
  gaps: FamilyPolicyGap[],
): string[] {
  const topMember = [...members].sort((left, right) => left.score - right.score)[0];
  const priorities: string[] = [];

  if (topMember) {
    priorities.push(
      t(
        locale,
        `优先补齐 ${topMember.name}（${topMember.relation}）的核心保障短板。`,
        `Prioritize core protection gaps for ${topMember.name}.`,
      ),
    );
  }

  if (gaps.some((gap) => gap.severity === 'high')) {
    priorities.push(
      t(
        locale,
        '先完成“医疗险 + 重疾险 + 寿险”基础结构，再补充意外险与附加责任。',
        'Build medical + critical illness + life coverage before add-ons.',
      ),
    );
  }

  priorities.push(
    t(
      locale,
      '建议每年复盘一次家庭保障结构，在收入变化、成员变化后立即更新。',
      'Review household protection yearly and after major life changes.',
    ),
  );

  return priorities;
}

function buildSummary(locale: InsightLocale, score: number, memberCount: number, gapCount: number): string {
  if (locale === 'zh') {
    return `家庭保障评分 ${score}/100，覆盖成员 ${memberCount} 人，识别到 ${gapCount} 项待改进风险。`;
  }
  return `Family score ${score}/100 with ${memberCount} members and ${gapCount} identified gaps.`;
}

function resolveRoleType(relation: string, age: number | null): MemberRoleType {
  const normalized = relation.toLowerCase();
  const isChildRelation = containsAny(normalized, ['子', 'child', 'daughter', 'son']);
  const isSeniorRelation = containsAny(normalized, ['父', '母', '祖', 'grand', 'elder', '老人']);
  const isCoreRelation = containsAny(normalized, ['本人', '配偶', 'self', 'spouse', 'husband', 'wife', '丈夫', '妻子']);

  if (isChildRelation || (age !== null && age <= 22)) {
    return 'child';
  }
  if (isSeniorRelation || (age !== null && age >= 60)) {
    return 'senior';
  }
  if (isCoreRelation || (age !== null && age >= 23 && age <= 60)) {
    return 'breadwinner';
  }
  return 'adult';
}

function buildFocusPoints(locale: InsightLocale, roleType: MemberRoleType): string[] {
  if (roleType === 'breadwinner') {
    return [
      t(locale, '收入中断风险', 'Income interruption risk'),
      t(locale, '重大疾病与康复支出', 'Critical illness and recovery cost'),
      t(locale, '负债与家庭抚养责任', 'Liabilities and dependent support'),
    ];
  }
  if (roleType === 'child') {
    return [
      t(locale, '门急诊和住院高频支出', 'Frequent outpatient/inpatient spending'),
      t(locale, '意外伤害风险', 'Accidental injury risk'),
      t(locale, '长期健康风险', 'Long-term health risk'),
    ];
  }
  if (roleType === 'senior') {
    return [
      t(locale, '慢病与住院医疗支出', 'Chronic disease and hospitalization costs'),
      t(locale, '失能护理成本', 'Long-term care cost'),
      t(locale, '医保与普惠补充医疗衔接', 'Public + inclusive supplemental coverage'),
    ];
  }
  return [
    t(locale, '基础医疗保障', 'Basic medical protection'),
    t(locale, '意外与重疾风险', 'Accident and critical illness risk'),
    t(locale, '保费可持续性', 'Premium sustainability'),
  ];
}

function buildPainPoints(
  locale: InsightLocale,
  roleType: MemberRoleType,
  coverage: FamilyInsight['policyCoverage'],
): string[] {
  const points: string[] = [];
  if (!coverage.medical) {
    points.push(t(locale, '缺少医疗险，报销杠杆不足。', 'Missing medical reimbursement coverage.'));
  }
  if (!coverage.accident) {
    points.push(t(locale, '缺少意外险，突发事故缓冲不足。', 'Missing accident protection.'));
  }
  if (roleType === 'breadwinner' && !coverage.life) {
    points.push(t(locale, '家庭支柱缺少寿险，收入替代风险高。', 'Breadwinner lacks life insurance.'));
  }
  if (roleType === 'breadwinner' && !coverage.critical) {
    points.push(t(locale, '家庭支柱缺少重疾险，现金流冲击风险高。', 'Breadwinner lacks critical illness coverage.'));
  }
  if (roleType === 'senior') {
    points.push(
      t(
        locale,
        '长辈更易面临慢病与失能风险，仅靠社保通常不足。',
        'Seniors are more exposed to chronic disease and long-term care risk.',
      ),
    );
  }
  return points;
}

function buildMemberRecommendations(
  locale: InsightLocale,
  roleType: MemberRoleType,
  coverage: FamilyInsight['policyCoverage'],
): MemberRecommendation[] {
  const recs: MemberRecommendation[] = [];

  if (roleType === 'breadwinner') {
    recs.push(makeRecommendation(locale, '定期寿险', 'high', '优先覆盖收入替代责任。', 'Prioritize income replacement.'));
    recs.push(makeRecommendation(locale, '重疾险', 'high', '覆盖大病康复与收入损失。', 'Cover critical illness and income loss.'));
    recs.push(makeRecommendation(locale, '医疗险', 'high', '补足住院与特药支出。', 'Cover hospitalization and special drugs.'));
    recs.push(makeRecommendation(locale, '意外险', 'medium', '提升伤残与意外医疗风险缓冲。', 'Add accident/disability protection.'));
  } else if (roleType === 'child') {
    recs.push(makeRecommendation(locale, '医疗险', 'high', '儿童就医频率高，优先配置报销类保障。', 'Children need reimbursement coverage first.'));
    recs.push(makeRecommendation(locale, '意外险', 'high', '活动场景多，意外风险较高。', 'Children have higher accidental exposure.'));
    recs.push(makeRecommendation(locale, '少儿重疾险', 'medium', '补齐重大疾病一次性给付。', 'Add lump-sum critical illness support.'));
  } else if (roleType === 'senior') {
    recs.push(makeRecommendation(locale, '医疗险/防癌医疗险', 'high', '优先覆盖住院与慢病支出。', 'Prioritize hospitalization and chronic disease expenses.'));
    recs.push(makeRecommendation(locale, '老年意外险', 'high', '覆盖跌倒骨折等高发风险。', 'Cover common senior accident risks.'));
    recs.push(
      makeRecommendation(
        locale,
        '地方普惠补充医保（如广州穗岁康）',
        'medium',
        '若常住广州，可关注穗岁康等普惠产品（以当年政策为准）。',
        'For Guangzhou residents, consider inclusive plans like Suisuikang.',
      ),
    );
    recs.push(makeRecommendation(locale, '长护险衔接规划', 'medium', '提前规划失能护理风险。', 'Plan for long-term care risk.'));
  } else {
    recs.push(makeRecommendation(locale, '医疗险', 'high', '优先覆盖基础医疗支出风险。', 'Prioritize medical expense coverage.'));
    recs.push(makeRecommendation(locale, '意外险', 'medium', '补足突发事故保障。', 'Add accident protection.'));
    recs.push(makeRecommendation(locale, '重疾险', 'medium', '按预算补齐重大疾病风险。', 'Add critical illness coverage by budget.'));
  }

  if (!coverage.medical) {
    recs.unshift(
      makeRecommendation(locale, '医疗险', 'high', '家庭整体缺少医疗保障，建议优先补齐。', 'Household lacks medical coverage; prioritize this first.'),
    );
  }
  if (roleType === 'breadwinner' && !coverage.life) {
    recs.unshift(
      makeRecommendation(locale, '定期寿险', 'high', '家庭支柱应优先配置寿险。', 'Breadwinner should prioritize life insurance.'),
    );
  }

  return recs.slice(0, 5);
}

function calculateMemberScore(roleType: MemberRoleType, coverage: FamilyInsight['policyCoverage']): number {
  let score = roleType === 'breadwinner'
    ? 86
    : roleType === 'senior'
        ? 78
        : roleType === 'child'
            ? 76
            : 70;

  if (!coverage.medical) {
    score -= roleType === 'senior' ? 18 : 14;
  }
  if (!coverage.accident) {
    score -= 10;
  }
  if (roleType === 'breadwinner' && !coverage.life) {
    score -= 18;
  }
  if (roleType === 'breadwinner' && !coverage.critical) {
    score -= 14;
  }
  if (roleType === 'child' && !coverage.critical) {
    score -= 8;
  }

  return roundToInt(clamp(score, 0, 100));
}

function isExpiringSoon(endDate: string | null): boolean {
  if (!endDate) {
    return false;
  }
  const date = new Date(endDate);
  if (Number.isNaN(date.getTime())) {
    return false;
  }
  const now = new Date();
  const diff = Math.ceil((date.getTime() - now.getTime()) / 86400000);
  return diff >= 0 && diff <= 30;
}

function calculateAge(birthDate: string | null): number | null {
  if (!birthDate) {
    return null;
  }
  const date = new Date(birthDate);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  const now = new Date();
  let age = now.getFullYear() - date.getFullYear();
  const passedBirthday = now.getMonth() > date.getMonth()
    || (now.getMonth() === date.getMonth() && now.getDate() >= date.getDate());
  if (!passedBirthday) {
    age -= 1;
  }
  return age < 0 ? null : age;
}

function buildSourceReferences(locale: InsightLocale): FamilySourceReference[] {
  return sourceSeeds.map((item) => ({
    title: locale === 'zh' ? item.titleZh : item.titleEn,
    note: locale === 'zh' ? item.noteZh : item.noteEn,
    url: item.url,
  }));
}

function makeRecommendation(
  locale: InsightLocale,
  insuranceType: string,
  priority: PriorityLevel,
  zhReason: string,
  enReason: string,
): MemberRecommendation {
  return {
    insuranceType: locale === 'zh' ? insuranceType : toEnglishInsuranceType(insuranceType),
    priority,
    reason: t(locale, zhReason, enReason),
  };
}

function toEnglishInsuranceType(value: string): string {
  const map: Record<string, string> = {
    '定期寿险': 'Term Life Insurance',
    '重疾险': 'Critical Illness Insurance',
    '医疗险': 'Medical Insurance',
    '意外险': 'Accident Insurance',
    '少儿重疾险': 'Children Critical Illness Insurance',
    '医疗险/防癌医疗险': 'Medical / Cancer Medical Insurance',
    '老年意外险': 'Senior Accident Insurance',
    '地方普惠补充医保（如广州穗岁康）': 'Regional Inclusive Supplemental Medical Plan',
    '长护险衔接规划': 'Long-Term Care Planning',
  };
  return map[value] ?? value;
}

function containsAny(text: string, keywords: string[]): boolean {
  return keywords.some((item) => text.includes(item.toLowerCase()));
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
