import assert from 'node:assert/strict';
import test from 'node:test';

import {
  NbsIncomeBenchmarkProvider,
  parseNbsIncomePayload,
} from '../src/modules/benchmarks/provider';

test('parseNbsIncomePayload should pick latest year for target indicator', () => {
  const payload = {
    returndata: {
      datanodes: [
        {
          code: 'zb.A0A0101_sj.2024',
          data: { data: 41314, strdata: '41314' },
          wds: [{ wdcode: 'sj', valuecode: '2024' }],
        },
        {
          code: 'zb.A0A0101_sj.2025',
          data: { data: 43377, strdata: '43377' },
          wds: [{ wdcode: 'sj', valuecode: '2025' }],
        },
      ],
    },
  } as Record<string, unknown>;

  const parsed = parseNbsIncomePayload(payload, 'A0A0101');
  assert.deepEqual(parsed, {
    annualIncome: 43377,
    year: 2025,
  });
});

test('parseNbsIncomePayload should return null for empty datanodes', () => {
  const payload = {
    returndata: {
      datanodes: [],
    },
  } as Record<string, unknown>;

  const parsed = parseNbsIncomePayload(payload, 'A0A0101');
  assert.equal(parsed, null);
});

test('parseNbsIncomePayload should return null for non-numeric value', () => {
  const payload = {
    returndata: {
      datanodes: [
        {
          code: 'zb.A0A0101_sj.2025',
          data: { strdata: 'N/A' },
          wds: [{ wdcode: 'sj', valuecode: '2025' }],
        },
      ],
    },
  } as Record<string, unknown>;

  const parsed = parseNbsIncomePayload(payload, 'A0A0101');
  assert.equal(parsed, null);
});

test('NbsIncomeBenchmarkProvider should classify html challenge as html failure', async () => {
  const fetchImpl = (async () => new Response('<!DOCTYPE html><html></html>', { status: 200 })) as typeof fetch;
  const provider = new NbsIncomeBenchmarkProvider({
    endpoint: 'https://data.stats.gov.cn/easyquery.htm',
    dbCode: 'hgnd',
    indicator: 'A0A0101',
    source: 'nbs-hgnd-a0a0101',
    region: 'CN',
    currency: 'CNY',
    fetchImpl,
  });

  const result = await provider.fetchLatest(new AbortController().signal);
  assert.deepEqual(result, {
    ok: false,
    reason: 'html',
  });
});
