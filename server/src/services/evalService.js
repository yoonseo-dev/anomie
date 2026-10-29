const fs = require('fs/promises');
const path = require('path');
const { randomUUID } = require('crypto');
const claudeService = require('./claudeService');
const { claudeCost, VISION_USD_PER_UNIT, KRW_PER_USD } = require('../eval/pricing');

const RUBRIC_PATH = path.join(__dirname, '../eval/rubric.md');
const DEFAULT_LOG_DIR = path.join(__dirname, '../../logs');

// 등급 구간 (rubric.md "종합 점수와 등급"과 같게 유지)
const BANDS = [
  [4.5, '우수'],
  [3.5, '양호'],
  [2.5, '보통'],
  [1.5, '미흡'],
  [-Infinity, '부적합'],
];

const logDir = () => process.env.ANALYSIS_LOG_DIR || DEFAULT_LOG_DIR;
// ANALYSIS_LOG=off: 기록하지 않음 (테스트)
// ANALYSIS_JUDGE=off: 비용·지표만 기록하고 채점은 건너뜀
// ANALYSIS_JUDGE_UNTIL=YYYY-MM-DD: 그날까지만 채점 (실측 기간). 지나면 자동으로 채점을 끈다
const loggingOn = () => process.env.ANALYSIS_LOG !== 'off';
function judgeOn(now = new Date()) {
  if (process.env.ANALYSIS_JUDGE === 'off') return false;
  const until = process.env.ANALYSIS_JUDGE_UNTIL;
  if (!until) return true;
  const end = new Date(`${until}T23:59:59`);
  if (isNaN(end.getTime())) {
    console.error(`[기록] ANALYSIS_JUDGE_UNTIL 형식이 잘못됐습니다 (YYYY-MM-DD): ${until}. 채점을 끕니다`);
    return false;
  }
  return now <= end;
}

const tokensOf = (u) => ({
  input: u.inputTokens,
  output: u.outputTokens,
  ...(u.cacheWriteTokens || u.cacheReadTokens ? { cacheWrite: u.cacheWriteTokens, cacheRead: u.cacheReadTokens } : {}),
});

const round = (n, digits) => (n == null ? null : Number(n.toFixed(digits)));

function overallScore(scores) {
  const values = Object.values(scores ?? {})
    .filter(Boolean)
    .map((s) => s.score);
  if (!values.length) return { overall: null, band: null };
  const overall = round(values.reduce((a, b) => a + b, 0) / values.length, 1);
  return { overall, band: BANDS.find(([min]) => overall >= min)[1] };
}

// 채점자 없이 서버가 계산하는 지표 (rubric.md "자동 지표")
function autoMetrics({ rawTags, tags, existingTags }) {
  const existingNames = new Set(existingTags.map((t) => t.name));
  const withExcerpt = tags.filter((t) => t.excerpt !== undefined);
  return {
    tagCount: tags.length,
    newTags: tags.filter((t) => t.isNew).length,
    reusedTags: tags.filter((t) => !t.isNew).length,
    nameMatched: rawTags.filter((t) => !t.existingTag && existingNames.has(t.name)).length,
    excerptVerifiedRate: withExcerpt.length
      ? round(withExcerpt.filter((t) => t.excerptVerified).length / withExcerpt.length, 2)
      : null,
    avgTagNameLength: tags.length ? round(tags.reduce((a, t) => a + t.name.length, 0) / tags.length, 1) : null,
  };
}

// 해당 없는 항목은 채점자가 점수를 줬어도 null로 바꾼다 (rubric.md: 기존 태그 없으면 reuse, 기사면 excerpt_choice)
function dropNotApplicable(scores, { kind, existingTags }) {
  return {
    ...scores,
    ...(existingTags.length === 0 && { reuse: null }),
    ...(kind !== 'book' && { excerpt_choice: null }),
  };
}

function costOf({ analysisUsage, judgeUsage, ocrUnits }) {
  const analysisUsd = claudeCost(analysisUsage);
  const judgeUsd = judgeUsage ? claudeCost(judgeUsage) : 0;
  const ocrUsd = ocrUnits * VISION_USD_PER_UNIT;
  const totalUsd = [analysisUsd, judgeUsd, ocrUsd].every((v) => v != null) ? analysisUsd + judgeUsd + ocrUsd : null;
  return {
    analysisUsd: round(analysisUsd, 6),
    judgeUsd: round(judgeUsd, 6),
    ocrUsd: round(ocrUsd, 6), // 정가 기준. 매달 1,000장까지는 실제로 무료
    totalUsd: round(totalUsd, 6),
    totalKrw: totalUsd == null ? null : Math.round(totalUsd * KRW_PER_USD),
  };
}

// 분석 한 번을 채점하고 server/logs/analysis-YYYY-MM.jsonl에 한 줄로 남긴다.
// 원문(기사 본문·OCR 텍스트)은 채점에만 쓰고 기록하지 않는다. 실패해도 분석 응답에는 영향이 없다.
async function recordAnalysis({ kind, userId, input, source, existingTags, rawTags, result, usage, ocrUnits = 0 }) {
  if (!loggingOn()) return null;

  const entry = {
    id: randomUUID(),
    at: new Date().toISOString(),
    kind,
    userId,
    input,
    models: { analysis: usage.model },
    tokens: { analysis: tokensOf(usage), judge: null },
    ocrUnits,
    cost: null,
    metrics: autoMetrics({ rawTags, tags: result.tags, existingTags }),
    scores: null,
    overall: null,
    band: null,
    judgeError: null,
    result: {
      summary: result.summary,
      tags: result.tags.map(({ name, isNew, category, reason, excerpt, excerptVerified }) => ({
        name,
        isNew,
        category,
        reason,
        ...(excerpt !== undefined && { excerpt, excerptVerified }),
      })),
    },
  };

  let judgeUsage = null;
  if (judgeOn()) {
    try {
      const rubric = await fs.readFile(RUBRIC_PATH, 'utf8');
      const judged = await claudeService.judgeAnalysis({
        rubric,
        kind,
        source,
        existingTagNames: existingTags.map((t) => t.name),
        // 글자 일치 검증 결과는 보여 주지 않는다 (채점자가 내용 대신 검증 결과로 감점하지 않도록)
        result: { summary: result.summary, tags: result.tags.map(({ excerptVerified, ...t }) => t) },
      });
      judgeUsage = judged.usage;
      entry.models.judge = judged.usage.model;
      entry.tokens.judge = tokensOf(judged.usage);
      entry.scores = dropNotApplicable(judged.scores, { kind, existingTags });
      Object.assign(entry, overallScore(entry.scores));
    } catch (err) {
      entry.judgeError = err.message;
    }
  }
  entry.cost = costOf({ analysisUsage: usage, judgeUsage, ocrUnits });

  const file = path.join(logDir(), `analysis-${entry.at.slice(0, 7)}.jsonl`);
  await fs.mkdir(logDir(), { recursive: true });
  await fs.appendFile(file, JSON.stringify(entry) + '\n');
  console.log(
    `[기록] ${kind} | ${entry.cost.totalKrw ?? '?'}원 | ` +
      (entry.overall != null ? `${entry.overall}점 ${entry.band}` : `채점 없음${entry.judgeError ? ` (${entry.judgeError})` : ''}`)
  );
  return entry;
}

// 관계 제안 한 번(1·2단계)의 비용과 결과 수를 server/logs/relations-YYYY-MM.jsonl에 남긴다 (채점 없음)
async function recordRelationRun({ userId, scrap, stage1, stage2, candidates, created }) {
  if (!loggingOn()) return null;
  const s1 = claudeCost(stage1);
  const s2 = stage2 ? claudeCost(stage2) : 0;
  const totalUsd = s1 != null && s2 != null ? s1 + s2 : null;
  const entry = {
    id: randomUUID(),
    at: new Date().toISOString(),
    kind: 'relation',
    userId,
    scrap,
    models: { stage1: stage1.model, stage2: stage2?.model ?? null },
    tokens: { stage1: tokensOf(stage1), stage2: stage2 ? tokensOf(stage2) : null },
    candidates,
    created,
    cost: {
      stage1Usd: round(s1, 6),
      stage2Usd: round(s2, 6),
      totalUsd: round(totalUsd, 6),
      totalKrw: totalUsd == null ? null : Math.round(totalUsd * KRW_PER_USD),
    },
  };
  await fs.mkdir(logDir(), { recursive: true });
  await fs.appendFile(path.join(logDir(), `relations-${entry.at.slice(0, 7)}.jsonl`), JSON.stringify(entry) + '\n');
  console.log(`[기록] relation | ${entry.cost.totalKrw ?? '?'}원 | 후보 ${candidates} → 제안 ${created}`);
  return entry;
}

// 응답을 기다리게 하지 않도록 기다리지 않고 실행한다. 실패는 로그로만 남긴다.
function recordInBackground(args) {
  recordAnalysis(args).catch((err) => console.error(`[기록] 실패: ${err.message}`));
}

module.exports = { recordAnalysis, recordInBackground, recordRelationRun, overallScore, autoMetrics, judgeOn };
