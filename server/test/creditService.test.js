const { test, describe, beforeEach, afterEach, after, mock } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const claudeService = require('../src/services/claudeService');
const creditService = require('../src/services/creditService');

// Haiku 4.5: 입력 $1, 출력 $5 / 100만 토큰 → $0.008
const usage = { model: 'claude-haiku-4-5-20251001', inputTokens: 3000, outputTokens: 1000 };

describe('creditService: 크레딧 잔액 장부', () => {
  let dir;

  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'anomie-credit-'));
    process.env.CREDIT_LOG_DIR = dir;
  });

  afterEach(() => {
    mock.restoreAll();
    fs.rmSync(dir, { recursive: true, force: true });
  });

  after(() => {
    delete process.env.CREDIT_LOG_DIR;
  });

  test('기준 잔액에서 호출 비용을 빼고, 줄마다 그 시점의 잔액을 남긴다', async () => {
    await creditService.setBalance(4.7);
    await creditService.recordUsage({ usage, what: '기사' });
    await creditService.recordUsage({ usage, what: '채점' });

    const entries = await creditService.readLedger();
    assert.deepEqual(
      entries.map(({ type, what, usd, balanceUsd }) => ({ type, what, usd, balanceUsd })),
      [
        { type: 'set', what: undefined, usd: 4.7, balanceUsd: 4.7 },
        { type: 'use', what: '기사', usd: 0.008, balanceUsd: 4.692 },
        { type: 'use', what: '채점', usd: 0.008, balanceUsd: 4.684 },
      ]
    );
    assert.ok(entries.every((e) => !isNaN(Date.parse(e.at))));
  });

  test('동시에 기록해도 같은 잔액에서 두 번 빼지 않는다', async () => {
    await creditService.setBalance(1);
    await Promise.all(Array.from({ length: 5 }, () => creditService.recordUsage({ usage, what: '기사' })));

    assert.equal(creditService.balanceOf(await creditService.readLedger()), 0.96);
  });

  test('충전은 더하고, 다시 맞추면 장부 추정과의 차이를 남긴다', async () => {
    await creditService.setBalance(4.7);
    await creditService.recordUsage({ usage, what: '기사' });
    await creditService.addCredit(10, '카드 충전');
    const set = await creditService.setBalance(14.5);

    assert.equal(set.driftUsd, -0.192);
    const entries = await creditService.readLedger();
    assert.equal(entries[2].balanceUsd, 14.692);
    assert.equal(entries[2].note, '카드 충전');
  });

  test('기준 잔액이 없으면 사용액만 남기고, 충전은 거부한다', async () => {
    const entry = await creditService.recordUsage({ usage, what: '기사' });
    assert.equal(entry.usd, 0.008);
    assert.equal(entry.balanceUsd, null);
    await assert.rejects(creditService.addCredit(10), /기준 잔액이 없습니다/);
  });

  test('단가를 모르는 모델이면 비용을 지어내지 않고 잔액을 그대로 둔다', async () => {
    await creditService.setBalance(4.7);
    const entry = await creditService.recordUsage({ usage: { ...usage, model: 'unknown-model' }, what: '기사' });
    assert.equal(entry.usd, null);
    assert.equal(entry.balanceUsd, 4.7);
  });

  test('Claude 호출은 응답 결과를 못 써도 비용을 장부에 남긴다', async () => {
    await creditService.setBalance(4.7);
    const recorded = mock.method(creditService, 'recordUsageInBackground', () => {});
    mock.method(claudeService.client.messages, 'stream', () => ({
      finalMessage: async () => ({
        stop_reason: 'max_tokens',
        usage: { input_tokens: 3000, output_tokens: 1000 },
        content: [{ type: 'text', text: '{"잘림' }],
      }),
    }));

    await assert.rejects(claudeService.analyzeArticleTags('본문'), { status: 502 });
    assert.equal(recorded.mock.callCount(), 1);
    assert.deepEqual(recorded.mock.calls[0].arguments[0], {
      usage: { ...usage, cacheWriteTokens: 0, cacheReadTokens: 0 },
      what: '기사',
    });
  });
});
