// PDF scan helpers that extract policy fields via AI or heuristics.
import pdfParse from 'pdf-parse';

import { env } from '../../config/env';

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
    source,
  };
}

function heuristicScan(text: string, fileName: string): PartialScan {
  const normalized = normalizeText(text);

  const period = matchDatePeriod(normalized);
  const policyNo =
    matchFirst(normalized, [
      /(?:保单号|保险单号|合同号|保险合同号|Policy\s*(?:No\.?|Number))\s*[:：]?\s*([A-Za-z0-9][A-Za-z0-9\-_/]{4,})/i,
    ]) ?? matchFirst(normalized, [/\b([A-Z]{1,6}-\d{4,}-\d{2,})\b/]);

  const insurerName =
    matchFirst(normalized, [
      /(?:保险公司|承保公司|保险人|Insurer)\s*[:：]?\s*([^\n\r]{2,50})/i,
    ]) ?? matchFirst(normalized, [/([^\n\r]{2,40}保险(?:股份)?有限公司)/]);

  const productName = matchFirst(normalized, [
    /(?:产品名称|险种名称|保险产品|Product\s*Name)\s*[:：]?\s*([^\n\r]{2,80})/i,
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
