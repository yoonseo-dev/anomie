// 분석 비용 계산용 단가 (10-29 기준). 바뀌면 여기만 고친다.
// 출처: Anthropic 모델 가격표, Google Cloud Vision 가격 페이지 (doc/plan.md 3단계 OCR 선정 기록)

// Claude: 100만 토큰당 달러. 캐시 쓰기는 입력 단가의 1.25배(5분 캐시), 캐시 읽기는 0.1배
// (cacheRead가 있으면 그 단가를 쓴다: Opus 5.5는 캐시 읽기가 $0.20로 0.05배)
// 생각(thinking) 토큰도 출력 단가로 계산된다
const CLAUDE_USD_PER_MTOK = {
  'claude-sonnet-5-5': { input: 2, output: 10 }, // 11-01 기준
  'claude-opus-5-5': { input: 4, output: 20, cacheRead: 0.2 }, // 11-01 기준
  'claude-haiku-4-5-20251001': { input: 1, output: 5 },
  'claude-haiku-5-5': { input: 0.1, output: 0.5 }, // 프롬프트 10만 토큰 이하 기준
};
const CACHE_WRITE_MULTIPLIER = 1.25;
const CACHE_READ_MULTIPLIER = 0.1;

// Vision DOCUMENT_TEXT_DETECTION: 매달 1,000장 무료, 그 뒤 1,000장당 $1.50.
// 그달 사용량은 서버가 알 수 없으므로 정가 기준 비용을 기록하고, 무료 사용량 차감은 리포트에서 따로 본다.
const VISION_USD_PER_UNIT = 1.5 / 1000;
const VISION_FREE_UNITS_PER_MONTH = 1000;

// 원화 환산용 고정 환율 (대략값)
const KRW_PER_USD = 1400;

function claudeCost({ model, inputTokens, outputTokens, cacheWriteTokens = 0, cacheReadTokens = 0 }) {
  const price = CLAUDE_USD_PER_MTOK[model];
  if (!price) return null; // 모르는 모델이면 비용을 지어내지 않는다
  const cacheRead = cacheReadTokens * (price.cacheRead ?? price.input * CACHE_READ_MULTIPLIER);
  const input = (inputTokens + cacheWriteTokens * CACHE_WRITE_MULTIPLIER) * price.input;
  return (input + cacheRead + outputTokens * price.output) / 1e6;
}

module.exports = { claudeCost, VISION_USD_PER_UNIT, VISION_FREE_UNITS_PER_MONTH, KRW_PER_USD };
