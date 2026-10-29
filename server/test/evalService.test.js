const { test, describe, before, beforeEach, afterEach, after, mock } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const claudeService = require('../src/services/claudeService');
const { recordAnalysis, overallScore, judgeOn } = require('../src/services/evalService');
const { claudeCost } = require('../src/eval/pricing');

const usage = { model: 'claude-haiku-4-5-20251001', inputTokens: 3000, outputTokens: 1000 };
const judgeUsage = { model: 'claude-haiku-4-5-20251001', inputTokens: 4000, outputTokens: 600 };

const s = (score) => ({ score, reason: '근거' });
const scores = { concept_fit: s(5), tag_naming: s(4), grounding: s(4), summary: s(5), reuse: null, excerpt_choice: s(3) };

const bookArgs = () => ({
  kind: 'book',
  userId: 'u1',
  input: { bookTitle: '불안', author: '알랭 드 보통', page: 30 },
  source: 'OCR 원문 텍스트',
  existingTags: [{ id: 't1', name: '아노미' }],
  rawTags: [{ name: '아노미', existingTag: null }, { name: '지위 불안', existingTag: null }],
  result: {
    summary: '요약',
    ocrText: 'OCR 원문 텍스트',
    tags: [
      { name: '아노미', isNew: false, category: '사회학', reason: 'r', excerpt: '가', excerptVerified: true },
      { name: '지위 불안', isNew: true, category: '사회학', reason: 'r', excerpt: '나', excerptVerified: false },
    ],
  },
  usage,
  ocrUnits: 1,
});

const readLog = (dir) =>
  fs
    .readdirSync(dir)
    .flatMap((f) => fs.readFileSync(path.join(dir, f), 'utf8').split('\n').filter(Boolean))
    .map((line) => JSON.parse(line));

describe('evalService: 분석 비용·채점 기록', () => {
  let dir;

  before(() => {
    process.env.ANALYSIS_LOG = 'on';
  });

  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'anomie-eval-'));
    process.env.ANALYSIS_LOG_DIR = dir;
    delete process.env.ANALYSIS_JUDGE;
  });

  afterEach(() => {
    mock.restoreAll();
    fs.rmSync(dir, { recursive: true, force: true });
  });

  after(() => {
    process.env.ANALYSIS_LOG = 'off';
    delete process.env.ANALYSIS_LOG_DIR;
  });

  test('비용·자동 지표·채점 점수를 월별 JSONL에 한 줄로 남기고, 원문은 남기지 않는다', async () => {
    const judge = mock.method(claudeService, 'judgeAnalysis', async () => ({ scores, usage: judgeUsage }));

    await recordAnalysis(bookArgs());

    const [entry] = readLog(dir);
    assert.match(fs.readdirSync(dir)[0], /^analysis-\d{4}-\d{2}\.jsonl$/);
    assert.equal(entry.kind, 'book');
    assert.deepEqual(entry.tokens, { analysis: { input: 3000, output: 1000 }, judge: { input: 4000, output: 600 } });
    // Haiku 4.5: 입력 $1, 출력 $5 / 100만 토큰. OCR 정가 $0.0015
    assert.equal(entry.cost.analysisUsd, 0.008);
    assert.equal(entry.cost.judgeUsd, 0.007);
    assert.equal(entry.cost.ocrUsd, 0.0015);
    assert.equal(entry.cost.totalUsd, 0.0165);
    assert.equal(entry.cost.totalKrw, 23);
    // null(reuse)을 뺀 5항목 평균 4.2 → 양호
    assert.equal(entry.overall, 4.2);
    assert.equal(entry.band, '양호');
    assert.deepEqual(entry.metrics, {
      tagCount: 2,
      newTags: 1,
      reusedTags: 1,
      nameMatched: 1, // '아노미'를 새 이름으로 제안 → 서버가 보정
      excerptVerifiedRate: 0.5,
      avgTagNameLength: 4,
    });
    assert.equal(entry.result.tags[1].excerptVerified, false);
    assert.ok(!JSON.stringify(entry).includes('OCR 원문 텍스트'));

    const judged = judge.mock.calls[0].arguments[0];
    assert.match(judged.rubric, /# 분석 결과 채점 기준표/);
    assert.equal(judged.source, 'OCR 원문 텍스트');
    assert.deepEqual(judged.existingTagNames, ['아노미']);
    assert.ok(!('ocrText' in judged.result));
    assert.ok(judged.result.tags.every((t) => !('excerptVerified' in t))); // 검증 결과는 채점자에게 숨긴다
  });

  test('해당 없는 항목에 채점자가 점수를 줘도 null로 바꾼다 (기존 태그 없음 → reuse, 기사 → excerpt_choice)', async () => {
    const all5 = { ...scores, concept_fit: s(3), reuse: s(5), excerpt_choice: s(5) };
    mock.method(claudeService, 'judgeAnalysis', async () => ({ scores: all5, usage: judgeUsage }));

    await recordAnalysis({ ...bookArgs(), kind: 'article', existingTags: [] });

    const [entry] = readLog(dir);
    assert.equal(entry.scores.reuse, null);
    assert.equal(entry.scores.excerpt_choice, null);
    assert.equal(entry.overall, 4); // 3, 4, 4, 5의 평균
  });

  test('채점이 실패해도 비용은 기록하고 오류를 남긴다', async () => {
    mock.method(claudeService, 'judgeAnalysis', async () => {
      throw new Error('채점 분석에 실패했습니다.');
    });

    await recordAnalysis(bookArgs());

    const [entry] = readLog(dir);
    assert.equal(entry.scores, null);
    assert.equal(entry.overall, null);
    assert.equal(entry.judgeError, '채점 분석에 실패했습니다.');
    assert.equal(entry.cost.judgeUsd, 0);
    assert.equal(entry.cost.totalUsd, 0.0095);
  });

  test('ANALYSIS_JUDGE=off면 채점 없이 기록하고, ANALYSIS_LOG=off면 아무것도 남기지 않는다', async () => {
    const judge = mock.method(claudeService, 'judgeAnalysis', async () => ({ scores, usage: judgeUsage }));

    process.env.ANALYSIS_JUDGE = 'off';
    await recordAnalysis(bookArgs());
    assert.equal(readLog(dir)[0].scores, null);

    process.env.ANALYSIS_LOG = 'off';
    await recordAnalysis(bookArgs());
    process.env.ANALYSIS_LOG = 'on';

    assert.equal(readLog(dir).length, 1);
    assert.equal(judge.mock.callCount(), 0);
  });

  test('모르는 모델이면 비용을 지어내지 않고 null', async () => {
    mock.method(claudeService, 'judgeAnalysis', async () => ({ scores, usage: judgeUsage }));

    await recordAnalysis({ ...bookArgs(), usage: { ...usage, model: 'unknown-model' } });

    const [entry] = readLog(dir);
    assert.equal(entry.cost.analysisUsd, null);
    assert.equal(entry.cost.totalKrw, null);
  });
});

describe('채점 기간·캐시 비용', () => {
  afterEach(() => {
    delete process.env.ANALYSIS_JUDGE;
    delete process.env.ANALYSIS_JUDGE_UNTIL;
  });

  test('ANALYSIS_JUDGE_UNTIL 날짜가 지나면 채점을 끈다 (그날 끝까지는 켬)', () => {
    process.env.ANALYSIS_JUDGE_UNTIL = '2026-11-30';
    assert.equal(judgeOn(new Date('2026-11-30T23:00:00')), true);
    assert.equal(judgeOn(new Date('2026-12-01T00:00:01')), false);

    process.env.ANALYSIS_JUDGE_UNTIL = '11월 말';
    assert.equal(judgeOn(), false); // 형식이 틀리면 비용이 새지 않도록 끈다

    delete process.env.ANALYSIS_JUDGE_UNTIL;
    assert.equal(judgeOn(), true);
    process.env.ANALYSIS_JUDGE = 'off';
    assert.equal(judgeOn(), false);
  });

  test('캐시 쓰기는 입력 단가의 1.25배, 읽기는 0.1배로 계산한다', () => {
    const base = { model: 'claude-haiku-5-5', inputTokens: 1000, outputTokens: 1000 };
    // Haiku 5.5: 입력 $0.1, 출력 $0.5 / 100만 토큰
    assert.equal(claudeCost(base), 0.0006);
    assert.equal(claudeCost({ ...base, cacheWriteTokens: 2800 }), (1000 + 3500) * 0.1e-6 + 1000 * 0.5e-6);
    assert.equal(claudeCost({ ...base, cacheReadTokens: 2800 }), (1000 + 280) * 0.1e-6 + 1000 * 0.5e-6);
  });
});

describe('evalService.overallScore: 등급 구간 (rubric.md와 같게)', () => {
  const only = (...xs) => Object.fromEntries(xs.map((x, i) => [`k${i}`, s(x)]));

  test('null을 뺀 평균으로 등급을 매긴다', () => {
    assert.deepEqual(overallScore(only(5, 4)), { overall: 4.5, band: '우수' });
    assert.deepEqual(overallScore(only(4, 3)), { overall: 3.5, band: '양호' });
    assert.deepEqual(overallScore(only(3, 2)), { overall: 2.5, band: '보통' });
    assert.deepEqual(overallScore(only(2, 1)), { overall: 1.5, band: '미흡' });
    assert.deepEqual(overallScore(only(1, 1)), { overall: 1, band: '부적합' });
    assert.deepEqual(overallScore({ a: null }), { overall: null, band: null });
  });
});
