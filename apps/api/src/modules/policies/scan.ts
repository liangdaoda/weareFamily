// PDF scan helpers that extract policy fields via AI or heuristics.
import pdfParse from 'pdf-parse';

import { env } from '../../config/env';
import {
  extractPolicySignalsFromText,
  mergeSignals,
  type PolicyCoverageItem,
  type PolicyFeatureSignals,
} from './insight';

export interface ScanPolicyResult {
  policyNo: string;
  insurerName: string;
  productName: string;
  premium: number;
  currency: string;
  startDate: string;
  endDate: string | null;
  aiRiskScore: number | null;
  aiNotes: string | null;
  signals: PolicyFeatureSignals;
  coverageItems: PolicyCoverageItem[];
  source: 'external' | 'heuristic';
}

interface PartialScan {
  policyNo?: string;
  insurerName?: string;
  productName?: string;
  premium?: number;
  currency?: string;
  startDate?: string;
  endDate?: string | null;
  aiRiskScore?: number | null;
  aiNotes?: string | null;
  signals?: Partial<PolicyFeatureSignals>;
  coverageItems?: PolicyCoverageItem[];
}

export async function scanPolicyFromPdf(buffer: Buffer, fileName: string): Promise<ScanPolicyResult> {
  const parsed = await pdfParse(buffer);
  const text = parsed.text ?? '';

  const heuristic = heuristicScan(text, fileName);

  if (env.aiScanProvider === 'external' && env.aiScanUrl) {
    try {
      const external = await externalScan(text, fileName, buffer);
      return mergeScan(heuristic, external, 'external');
    } catch (_) {
      const fallback = mergeScan(heuristic, {}, 'heuristic');
      fallback.aiNotes = `外部AI失败，已使用规则抽取。${fallback.aiNotes ?? ''}`.trim();
      return fallback;
    }
  }

  return mergeScan(heuristic, {}, 'heuristic');
}

async function externalScan(text: string, fileName: string, buffer: Buffer): Promise<PartialScan> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), env.aiScanTimeoutMs);

  try {
    const response = await fetch(env.aiScanUrl, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        fileName,
        // Send both OCR text and raw PDF base64 to support different AI contracts.
        text: text.slice(0, 40000),
        textLength: text.length,
        fileBase64: buffer.toString('base64'),
        mimeType: 'application/pdf',
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      throw new Error(`AI scan failed with status ${response.status}`);
    }

    const payload = (await response.json()) as Record<string, unknown>;
    return normalizeExternal(payload);
  } finally {
    clearTimeout(timeout);
  }
}

function normalizeExternal(payload: Record<string, unknown>): PartialScan {
  const obj = resolvePayloadObject(payload);

  return {
    policyNo: pickString(obj, ['policyNo', 'policy_number', 'policy_no', 'policyId', 'policy_id', '保单号', '保险单号', '合同号']),
    insurerName: pickString(obj, ['insurerName', 'insurer', 'insurer_name', 'company', 'companyName', '保险公司', '承保公司']),
    productName: pickString(obj, ['productName', 'product_name', 'product', 'planName', 'plan_name', '产品名称', '险种名称']),
    premium: pickNumber(obj, ['premium', 'annualPremium', 'amount', '保费', '年缴保费']),
    currency: pickString(obj, ['currency', '币种']),
    startDate: normalizeDateString(
      pickString(obj, ['startDate', 'effectiveDate', 'start_date', '生效日期', '起保日期']),
    ),
    endDate: normalizeNullableDateString(
      pickString(obj, ['endDate', 'expiryDate', 'end_date', '到期日期', '终止日期']),
    ),
    aiRiskScore: pickNumberOrNull(obj, ['aiRiskScore', 'riskScore', 'risk_score', '风险评分']),
    aiNotes: pickString(obj, ['aiNotes', 'notes', 'analysis', 'summary', '风险分析', '建议']),
    signals: {
      sumInsured: pickAmountOrNull(obj, ['sumInsured', 'sum_insured', 'coverageAmount', '保额', '保险金额']),
      hasMedicalCoverage: pickBooleanOrNull(obj, ['hasMedicalCoverage', 'medicalCoverage', '医疗保障']),
      hasCriticalIllnessCoverage: pickBooleanOrNull(
        obj,
        ['hasCriticalIllnessCoverage', 'criticalIllnessCoverage', '重疾保障'],
      ),
      hasSuddenDeathCoverage: pickBooleanOrNull(obj, ['hasSuddenDeathCoverage', 'suddenDeathCoverage', '猝死保障']),
      hasHospitalizationAllowance: pickBooleanOrNull(
        obj,
        ['hasHospitalizationAllowance', 'hospitalizationAllowance', '住院津贴'],
      ),
      hasOutpatientCoverage: pickBooleanOrNull(obj, ['hasOutpatientCoverage', 'outpatientCoverage', '门诊保障']),
    },
    coverageItems: pickCoverageItems(obj),
  };
}

function resolvePayloadObject(payload: Record<string, unknown>): Record<string, unknown> {
  const nestedData = payload.data;
  if (nestedData && typeof nestedData === 'object' && !Array.isArray(nestedData)) {
    return nestedData as Record<string, unknown>;
  }

  const nestedResult = payload.result;
  if (nestedResult && typeof nestedResult === 'object' && !Array.isArray(nestedResult)) {
    return nestedResult as Record<string, unknown>;
  }

  return payload;
}

function mergeScan(base: PartialScan, override: PartialScan, source: ScanPolicyResult['source']): ScanPolicyResult {
  const today = new Date().toISOString().slice(0, 10);
  const policyNo = (override.policyNo ?? base.policyNo)?.trim() || `AUTO-${Date.now()}`;
  const insurerName = (override.insurerName ?? base.insurerName)?.trim() || '未知保险公司';
  const productName = (override.productName ?? base.productName)?.trim() || '未识别产品';
  const premium = override.premium ?? base.premium ?? 0;
  const currency = (override.currency ?? base.currency ?? 'CNY').toUpperCase();
  const startDate = normalizeDateString(override.startDate ?? base.startDate) ?? today;
  const endDate = normalizeNullableDateString(override.endDate ?? base.endDate);
  const aiRiskScore = override.aiRiskScore ?? base.aiRiskScore ?? null;
  const aiNotes = override.aiNotes ?? base.aiNotes ?? `AI扫描来源: ${source}`;
  const signals = mergeSignals(base.signals, override.signals);
  const coverageItems = mergeCoverageItems(base.coverageItems, override.coverageItems, signals);

  return {
    policyNo,
    insurerName,
    productName,
    premium,
    currency,
    startDate,
    endDate,
    aiRiskScore,
    aiNotes,
    signals,
    coverageItems,
    source,
  };
}

function heuristicScan(text: string, fileName: string): PartialScan {
  const normalized = normalizeText(text);
  const signals = extractPolicySignalsFromText(normalized);
  const coverageItems = extractCoverageItemsFromText(normalized, signals);

  const period = matchDatePeriod(normalized);
  const policyNo =
    matchFirst(normalized, [
      /(?:保单号|保险单号|合同号|保险合同号|Policy\s*(?:No\.?|Number))\s*[:：]?\s*([A-Za-z0-9][A-Za-z0-9\-_/]{4,})/i,
    ]) ?? matchFirst(normalized, [/\b([A-Z]{1,6}-\d{4,}-\d{2,})\b/]);

  const insurerName =
    matchFirst(normalized, [
      /(?:公司名称)\s*[:：]?\s*([^\n\r]{2,80})/i,
      /(?:保险公司|承保公司|Insurer)\s*[:：]?\s*([^\n\r]{2,80})/i,
      /(?<!被)保险人(?:公司名称)?\s*[:：]?\s*([^\n\r]{2,80})/i,
    ]) ??
    matchFirst(normalized, [/([^\n\r]{2,60}保险(?:股份)?有限公司(?:[^\n\r]{0,20}分公司)?)/]);

  const productName = matchFirst(normalized, [
    /(?:产品名称|险种名称|保险产品|Product\s*Name)\s*[:：]?\s*([^\n\r]{2,80})/i,
    /([^\n\r]{2,80}保险单(?:（电子保单）)?)/,
  ]);

  const premiumRaw = matchFirst(normalized, [
    /(?:年缴保费|首年保费|保费|保险费|Premium)\s*[:：]?\s*(?:人民币|RMB|CNY|HKD|USD|¥|￥)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)/i,
    /(?:人民币|RMB|CNY|HKD|USD|¥|￥)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)/i,
  ]);

  const startDate =
    normalizeDateString(
      matchFirst(normalized, [
        /(?:生效日期|起保日期|合同生效日|保障起期|生效日)\s*[:：]?\s*([0-9]{4}[年./-][0-9]{1,2}[月./-][0-9]{1,2}日?)/,
      ]),
    ) ?? period?.start;

  const endDate =
    normalizeDateString(
      matchFirst(normalized, [
        /(?:终止日期|到期日期|保障止期|保障终止日)\s*[:：]?\s*([0-9]{4}[年./-][0-9]{1,2}[月./-][0-9]{1,2}日?)/,
      ]),
    ) ??
    period?.end ??
    null;

  return {
    policyNo: policyNo ? sanitizePolicyNo(policyNo) : undefined,
    insurerName: insurerName ? cleanLineValue(insurerName) : undefined,
    productName: productName ? cleanLineValue(productName) : undefined,
    premium: premiumRaw ? parseAmount(premiumRaw) : undefined,
    currency: detectCurrency(normalized),
    startDate,
    endDate,
    signals,
    coverageItems,
    aiNotes: `规则抽取(${fileName})`,
  };
}

function normalizeText(text: string): string {
  return text
    .normalize('NFKC')
    .replace(/\r/g, '\n')
    .replace(/\t/g, ' ')
    .replace(/[ ]{2,}/g, ' ');
}

function matchDatePeriod(text: string): { start: string; end: string } | undefined {
  const match = /(?:保险期间|保障期间)[^\n\r]{0,30}?自\s*([0-9]{4}[年./-][0-9]{1,2}[月./-][0-9]{1,2}日?)[^\n\r]{0,30}?(?:至|到)\s*([0-9]{4}[年./-][0-9]{1,2}[月./-][0-9]{1,2}日?)/.exec(text);
  if (!match) {
    return undefined;
  }

  const start = normalizeDateString(match[1]);
  const end = normalizeDateString(match[2]);
  if (!start || !end) {
    return undefined;
  }

  return { start, end };
}

function matchFirst(text: string, patterns: RegExp[]): string | undefined {
  for (const pattern of patterns) {
    const match = pattern.exec(text);
    if (match && match[1]) {
      return match[1].trim();
    }
  }
  return undefined;
}

function sanitizePolicyNo(value: string): string {
  return value.replace(/\s+/g, '').trim();
}

function cleanLineValue(value: string): string {
  return value
    .replace(/[;；。]+$/, '')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

function parseAmount(value: string): number {
  const numeric = value.replace(/,/g, '').trim();
  const parsed = Number(numeric);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function detectCurrency(text: string): string {
  const upper = text.toUpperCase();
  if (upper.includes('USD')) {
    return 'USD';
  }
  if (upper.includes('HKD')) {
    return 'HKD';
  }
  if (upper.includes('CNY') || upper.includes('RMB') || text.includes('人民币') || text.includes('￥') || text.includes('¥')) {
    return 'CNY';
  }
  return 'CNY';
}

function normalizeDateString(value: string | null | undefined): string | undefined {
  if (!value) {
    return undefined;
  }

  const raw = value.trim();
  const normalized = raw
    .replace(/年/g, '-')
    .replace(/月/g, '-')
    .replace(/日/g, '')
    .replace(/\./g, '-')
    .replace(/\//g, '-');

  const match = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(normalized);
  if (!match) {
    return undefined;
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return undefined;
  }

  const mm = String(month).padStart(2, '0');
  const dd = String(day).padStart(2, '0');
  return `${year}-${mm}-${dd}`;
}

function normalizeNullableDateString(value: string | null | undefined): string | null {
  if (value === null) {
    return null;
  }
  return normalizeDateString(value) ?? null;
}

function mergeCoverageItems(
  base: PolicyCoverageItem[] | undefined,
  override: PolicyCoverageItem[] | undefined,
  signals: PolicyFeatureSignals,
): PolicyCoverageItem[] {
  const preferred = (override && override.length > 0) ? override : base ?? [];
  const normalized = preferred
    .map(normalizeCoverageItem)
    .filter((item): item is PolicyCoverageItem => item !== null);
  if (normalized.length > 0) {
    return dedupeCoverageItems(normalized).slice(0, 24);
  }
  return buildFallbackCoverageItems(signals);
}

function extractCoverageItemsFromText(text: string, signals: PolicyFeatureSignals): PolicyCoverageItem[] {
  const patterns = [
    /([^\n\r]{2,40}?(?:责任|保障|给付|保险金|津贴|补偿|补助))\s*[:：]?\s*(?:人民币|rmb|cny|¥|￥)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(万)?/gi,
    /([^\n\r]{2,40}?(?:保额|限额))\s*[:：]?\s*(?:人民币|rmb|cny|¥|￥)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(万)?/gi,
  ];
  const items: PolicyCoverageItem[] = [];

  for (const pattern of patterns) {
    pattern.lastIndex = 0;
    let match = pattern.exec(text);
    while (match) {
      const name = cleanCoverageName(match[1]);
      if (name && !looksLikeNoiseCoverageName(name)) {
        const numeric = Number((match[2] ?? '').replace(/,/g, ''));
        const multiplier = match[3] ? 10000 : 1;
        items.push({
          code: normalizeCoverageCode(name),
          name,
          sumInsured: Number.isFinite(numeric) ? numeric * multiplier : null,
          description: null,
        });
      }
      match = pattern.exec(text);
    }
  }

  if (items.length > 0) {
    return dedupeCoverageItems(items).slice(0, 24);
  }
  return buildFallbackCoverageItems(signals);
}

function pickCoverageItems(obj: Record<string, unknown>): PolicyCoverageItem[] | undefined {
  const keys = ['coverageItems', 'coverages', 'coverage_items', 'benefits', '保障项目', '保障责任'];
  for (const key of keys) {
    const value = obj[key];
    if (!Array.isArray(value)) {
      continue;
    }

    const items = value
      .map((item) => normalizeCoverageItem(item))
      .filter((item): item is PolicyCoverageItem => item !== null);
    if (items.length > 0) {
      return dedupeCoverageItems(items).slice(0, 24);
    }
  }
  return undefined;
}

function normalizeCoverageItem(value: unknown): PolicyCoverageItem | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }

  const raw = value as Record<string, unknown>;
  const name = pickString(raw, ['name', 'title', 'item', 'coverageName', '保障项目', '保障责任', '责任名称']);
  if (!name) {
    return null;
  }

  const sumInsured = pickAmountOrNull(raw, ['sumInsured', 'sum_insured', 'amount', 'limit', '保额', '限额']) ?? null;
  const description = pickString(raw, ['description', 'desc', 'remark', 'note', '说明', '备注']) ?? null;

  return {
    code: normalizeCoverageCode(name),
    name: cleanCoverageName(name),
    sumInsured,
    description,
  };
}

function buildFallbackCoverageItems(signals: PolicyFeatureSignals): PolicyCoverageItem[] {
  const items: PolicyCoverageItem[] = [];
  if (signals.sumInsured !== null) {
    items.push({
      code: 'core_sum_insured',
      name: '基础保额',
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
  return items;
}

function dedupeCoverageItems(items: PolicyCoverageItem[]): PolicyCoverageItem[] {
  const map = new Map<string, PolicyCoverageItem>();
  for (const item of items) {
    const key = item.code || normalizeCoverageCode(item.name);
    const existing = map.get(key);
    if (!existing) {
      map.set(key, item);
      continue;
    }

    map.set(key, {
      ...existing,
      sumInsured: existing.sumInsured ?? item.sumInsured,
      description: existing.description ?? item.description,
    });
  }
  return Array.from(map.values());
}

function cleanCoverageName(value: string): string {
  return value
    .replace(/[;；。]+$/, '')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

function normalizeCoverageCode(name: string): string {
  return normalizeText(name)
    .replace(/[^\p{L}\p{N}]+/gu, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 48);
}

function looksLikeNoiseCoverageName(name: string): boolean {
  const normalized = normalizeText(name);
  const blocked = ['保费', '合计', '总计', '签章', '投保人', '被保险人', '保险期间'];
  return blocked.some((item) => normalized.includes(item));
}

function pickString(obj: Record<string, unknown>, keys: string[]): string | undefined {
  for (const key of keys) {
    const value = obj[key];
    if (value === undefined || value === null) {
      continue;
    }

    const str = String(value).trim();
    if (str.length > 0) {
      return str;
    }
  }
  return undefined;
}

function pickNumber(obj: Record<string, unknown>, keys: string[]): number | undefined {
  for (const key of keys) {
    const value = obj[key];
    if (value === undefined || value === null) {
      continue;
    }

    const str = String(value).replace(/,/g, '').trim();
    const num = Number(str);
    if (!Number.isNaN(num)) {
      return num;
    }
  }
  return undefined;
}

function pickNumberOrNull(obj: Record<string, unknown>, keys: string[]): number | null | undefined {
  const num = pickNumber(obj, keys);
  if (num === undefined) {
    return undefined;
  }
  return num;
}

function pickAmountOrNull(obj: Record<string, unknown>, keys: string[]): number | null | undefined {
  for (const key of keys) {
    const value = obj[key];
    if (value === undefined || value === null) {
      continue;
    }

    const raw = String(value).trim();
    if (raw.length === 0) {
      continue;
    }

    const normalized = raw.replace(/,/g, '');
    const multiplier = normalized.includes('万') ? 10000 : 1;
    const numeric = Number(normalized.replace(/[^\d.]/g, ''));
    if (!Number.isNaN(numeric) && numeric > 0) {
      return numeric * multiplier;
    }
  }
  return undefined;
}

function pickBooleanOrNull(obj: Record<string, unknown>, keys: string[]): boolean | null | undefined {
  for (const key of keys) {
    const value = obj[key];
    if (value === undefined || value === null) {
      continue;
    }
    if (typeof value === 'boolean') {
      return value;
    }

    const normalized = String(value).trim().toLowerCase();
    if (['1', 'true', 'yes', 'y', '是', '有', '包含', '覆盖'].includes(normalized)) {
      return true;
    }
    if (['0', 'false', 'no', 'n', '否', '无', '不包含', '不覆盖'].includes(normalized)) {
      return false;
    }
  }
  return undefined;
}
