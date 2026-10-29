// 분석 비용·채점 기록 요약. 사용: npm run eval:report [-- --month 2026-10] [-- --last 20]
// 기록 파일: server/logs/analysis-YYYY-MM.jsonl (evalService가 분석마다 한 줄씩 남긴다)
// 채점 기준은 src/eval/rubric.md
const fs = require('fs');
const path = require('path');
const { VISION_FREE_UNITS_PER_MONTH, KRW_PER_USD, VISION_USD_PER_UNIT } = require('../src/eval/pricing');

const LOG_DIR = process.env.ANALYSIS_LOG_DIR || path.join(__dirname, '../logs');

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 ? process.argv[i + 1] : fallback;
}

const month = arg('month', new Date().toISOString().slice(0, 7));
const last = Number(arg('last', 10));
const file = path.join(LOG_DIR, `analysis-${month}.jsonl`);

if (!fs.existsSync(file)) {
  console.log(`${month} 기록이 없습니다 (${file})`);
  process.exit(0);
}

const entries = fs
  .readFileSync(file, 'utf8')
  .split('\n')
  .filter(Boolean)
  .map((line) => JSON.parse(line));

const avg = (xs) => {
  const v = xs.filter((x) => x != null);
  return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null;
};
const fmt = (n, d = 1) => (n == null ? '-' : n.toFixed(d));
const krw = (n) => (n == null ? '-' : `${Math.round(n).toLocaleString()}원`);

console.log(`\n# 분석 기록 요약 (${month}, ${entries.length}건)\n`);

for (const kind of ['article', 'book']) {
  const list = entries.filter((e) => e.kind === kind);
  if (!list.length) continue;
  const name = kind === 'article' ? '기사' : '책';
  const totalKrw = list.reduce((a, e) => a + (e.cost?.totalKrw ?? 0), 0);
  const bands = {};
  for (const e of list) bands[e.band ?? '채점 없음'] = (bands[e.band ?? '채점 없음'] ?? 0) + 1;

  console.log(`## ${name} (${list.length}건)`);
  console.log(`- 비용: 평균 ${krw(totalKrw / list.length)} / 합계 ${krw(totalKrw)} (분석 + 채점 + OCR 정가)`);
  console.log(
    `- 비용 내역 평균: 분석 ${krw(avg(list.map((e) => e.cost?.analysisUsd)) * KRW_PER_USD)}, ` +
      `채점 ${krw(avg(list.map((e) => e.cost?.judgeUsd)) * KRW_PER_USD)}` +
      (kind === 'book' ? `, OCR ${krw(avg(list.map((e) => e.cost?.ocrUsd)) * KRW_PER_USD)}` : '')
  );
  console.log(`- 종합 점수 평균: ${fmt(avg(list.map((e) => e.overall)))} / 등급: ${Object.entries(bands).map(([b, n]) => `${b} ${n}`).join(', ')}`);

  const items = [...new Set(list.flatMap((e) => Object.keys(e.scores ?? {})))];
  const itemLine = items
    .map((k) => [k, avg(list.map((e) => e.scores?.[k]?.score))])
    .filter(([, v]) => v != null)
    .map(([k, v]) => `${k} ${fmt(v)}`)
    .join(', ');
  if (itemLine) console.log(`- 항목별 평균: ${itemLine}`);

  const m = (key) => avg(list.map((e) => e.metrics?.[key]));
  console.log(
    `- 자동 지표 평균: 태그 ${fmt(m('tagCount'))}개 (새 ${fmt(m('newTags'))}, 재사용 ${fmt(m('reusedTags'))}, 이름 보정 ${fmt(m('nameMatched'))}), ` +
      `태그 이름 ${fmt(m('avgTagNameLength'))}자` +
      (kind === 'book' ? `, 근거 문장 일치율 ${fmt(m('excerptVerifiedRate') * 100, 0)}%` : '')
  );
  console.log();
}

const ocrUnits = entries.reduce((a, e) => a + (e.ocrUnits ?? 0), 0);
const billable = Math.max(0, ocrUnits - VISION_FREE_UNITS_PER_MONTH);
console.log(
  `OCR: 이번 달 ${ocrUnits}장 (무료 ${VISION_FREE_UNITS_PER_MONTH}장 차감 후 실제 청구 예상 ${krw(billable * VISION_USD_PER_UNIT * KRW_PER_USD)}). ` +
    `이 서버 밖에서 쓴 사용량은 포함되지 않음\n`
);

console.log(`## 최근 ${Math.min(last, entries.length)}건`);
for (const e of entries.slice(-last).reverse()) {
  const what = e.kind === 'article' ? e.input?.title : `${e.input?.bookTitle} ${e.input?.page ?? ''}쪽`;
  const tags = e.result?.tags?.map((t) => t.name + (t.excerptVerified === false ? '(확인 필요)' : '')).join(', ');
  console.log(
    `- ${e.at.slice(5, 16).replace('T', ' ')} | ${e.kind === 'article' ? '기사' : '책'} | ${krw(e.cost?.totalKrw)} | ` +
      `${e.overall != null ? `${fmt(e.overall)}점 ${e.band}` : e.judgeError ? '채점 실패' : '채점 없음'} | ${what} | ${tags}`
  );
}
console.log(`\n항목별 판단 근거는 기록 파일의 scores.<항목>.reason에 있습니다: ${file}`);
