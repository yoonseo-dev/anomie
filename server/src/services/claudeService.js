const Anthropic = require('@anthropic-ai/sdk');
const httpError = require('../utils/httpError');
const creditService = require('./creditService');

const client = new Anthropic();

const MODEL = 'claude-haiku-4-5-20251001';
// 채점용 모델. 기준표(약 2,800토큰)를 프롬프트 캐시에 올리려면 최소 길이가 512토큰인 모델이어야 한다
// (Haiku 4.5는 4,096토큰 미만이면 캐시되지 않음). 단가도 Haiku 4.5의 1/10 (10-29)
const JUDGE_MODEL = 'claude-haiku-5-5';

// Tag.category에 저장하는 고정 분야 목록. 목록 밖이면 "기타" (doc/plan.md 3장)
const CATEGORIES = ['사회학', '철학', '정치학', '경제학', '심리학', '인류학', '커뮤니케이션학', '기타'];

// 기사·책 공통 태그 기준. source는 "기사" 또는 "책 구절"
const tagRules = (source) => `태그 선정 기준:
1. 학문적 근거 — 반드시 특정 학자, 이론, 학파와 직접 연결되는 개념만 선택한다. 막연한 키워드나 일상 용어는 제외한다.
2. 변별력 — 이 ${source}에 특별히 적합한 태그여야 한다. 어떤 글에나 붙여도 어색하지 않을 태그는 제외한다.
3. 태그 수 제한 — 최대 3개. 억지로 채우지 말고 진짜 해당되는 것만 선택한다.
4. 태그 이름 — 학계에서 통용되는 개념어를 짧은 명사구로 쓴다 (보통 2~8자). 글의 내용을 문장처럼 풀어 쓰지 않는다. 다른 글에도 그대로 붙일 수 있는 이름이어야 다른 스크랩과 연결된다.
   - 좋은 예: 아노미, 지위 불안, 인정 투쟁, 상대적 박탈감, 낙인 효과, 사회적 자본
   - 나쁜 예: "사회적 지위의 조건부 인정", "부모의 무조건적 사랑과 성인 관계의 조건성"
5. 확신 원칙 — 억지로 끼워 맞추지 않되, 합리적 학문적 근거가 있다면 반드시 태그를 붙인다. ${source}에서 사회적 현상이나 개념이 분명히 드러난다면 최소 1개는 포함한다.

사용자의 기존 태그 재사용:
- 사용자 메시지에 "기존 태그" 목록이 번호(T1, T2 …)와 함께 주어진다.
- 고른 개념이 기존 태그와 같은 개념이면(표기·띄어쓰기·동의어가 달라도) 반드시 그 번호를 existingTag에 넣는다. 이때 name에는 기존 태그 이름을 그대로 쓰고 description은 null로 둔다.
- 기존 태그 중 같은 개념이 없을 때만 existingTag를 null로 두고 새 태그 이름을 name에 쓴다.
- 새 태그일 때 similarExistingTags에는 사용자가 대신 고를 만한 비슷한 기존 태그 번호를 최대 3개 넣는다. 없거나 기존 태그를 재사용했으면 빈 배열로 둔다.
- 목록에 없는 번호는 절대 쓰지 않는다.

태그 각 필드 작성 기준:
- category: 다음 중 하나 — ${CATEGORIES.join(', ')}. 어디에도 맞지 않으면 "기타".
- description: (새 태그만) 개념의 학문적 기원(제안한 학자와 시대), 핵심 내용, 관련 이론적 맥락을 3~4문장으로 작성한다. 확실하지 않은 학자 이름이나 연도는 쓰지 않는다.
- explanation: 이 ${source}의 구체적인 맥락에서 해당 개념이 어떻게 드러나는지 3~4문장으로 설명한다.
- reason: 이 태그를 선택한 핵심 근거를 한두 문장으로 간결하게 요약한다.`;

const ARTICLE_SYSTEM_PROMPT = `당신은 사회학 전문가입니다. 주어진 뉴스 기사를 분석하여 관련 학문적 개념 태그, 기사 요약, 기사 평론, 기사 분석을 지정된 JSON 형식으로 반환하세요.

${tagRules('기사')}

기사 필드 작성 기준:
- summary: 기사의 핵심 사실과 쟁점을 2~3문장으로 요약한다. 나중에 원문 대신 이 요약만 보고 다른 스크랩과의 개념 연결을 판단하므로, 누가·무엇을·왜가 드러나게 쓴다.
- 아래 4가지 분석 항목은 억지로 채우지 않는다. 의미 있는 분석이 가능한 항목만 2~3문장으로 작성하고, 분석 가치가 없으면 반드시 null을 반환한다.
- commentary: 기사가 다루는 사회적 현상의 의미, 한계, 시사점을 중립적 학술 시각으로 서술한다. 특정 입장을 지지하거나 비판하지 않는다.
- framing: 기사가 사건을 어떤 단어와 구도로 표현하는지 분석한다. 특정 표현 선택(예: "공권력 투입" vs "강제 진압"), 무엇을 부각하고 무엇을 생략했는지 짚는다. 사실 보도 위주이거나 특정 프레임이 뚜렷하지 않으면 null.
- rhetoric: 기사 속 인물 발언이나 주장이 어떤 논리 구조와 전제를 갖는지, 어떤 설득 전략(공포 호소, 권위 호소 등)을 쓰는지 분석한다. 발언·주장이 거의 없거나 단순 사실 나열이면 null.
- stakeholders: 사건에 등장하는 행위자들이 각각 무엇을 원하고 누구와 대립하는지 정리한다. 이해관계가 복잡하거나 대립 구도가 뚜렷한 기사에서만 작성하고, 단순 사안이면 null.
- values: 기사가 당연하게 전제하는 가치 판단을 짚어내고, 그것이 어떤 정치철학적·윤리적 입장과 연결되는지 설명한다. 가치 전제가 불분명하거나 중립적 보도이면 null.`;

const BOOK_SYSTEM_PROMPT = `당신은 사회학·철학 전문가입니다. 책 한 페이지를 OCR로 읽은 텍스트가 주어집니다. 관련 학문적 개념 태그와 구절 요약을 지정된 JSON 형식으로 반환하세요.

OCR 텍스트 다루기:
- 사진을 OCR로 읽은 것이라 본문이 아닌 글자(쪽번호, 머리말, 책 제목, 날짜, 앱 화면 표시 등)가 섞이거나 줄 순서가 어긋날 수 있다. 본문이 아닌 글자는 무시한다.
- 줄 끝에서 단어가 끊겨 있을 수 있다 (예: "우리의 자" / "질을").

${tagRules('책 구절')}
- excerpts: 이 태그의 근거가 되는 본문을 OCR 텍스트에서 골라 옮긴 구간 목록 (1~3개, 합쳐서 1~3문장).
  - 각 구간은 OCR 텍스트에서 **끊기지 않고 이어진 부분**이어야 한다. 떨어진 두 문장을 하나의 구간으로 이어 붙이지 않는다. 떨어진 문장이 필요하면 구간을 나눈다.
  - **한 글자도 바꾸지 않고 그대로** 옮긴다. 맞춤법이나 OCR 오류를 고치지 않고, 접속사("그러나" 등)를 빼거나 말을 바꾸지 않는다. 줄바꿈은 공백 하나로 바꿔도 된다.
  - 본문이 아닌 글자는 넣지 않는다. 태그마다 그 개념이 가장 잘 드러나는 다른 부분을 고른다.

구절 필드 작성 기준:
- summary: 이 페이지에서 저자가 말하는 핵심 주장을 2~3문장으로 요약한다. 나중에 원문 대신 이 요약만 보고 다른 스크랩(뉴스 등)과의 개념 연결을 판단하므로, 주장의 내용이 드러나게 쓴다.`;

const nullableString = { anyOf: [{ type: 'string' }, { type: 'null' }] };

// 태그 하나의 스키마. 책은 근거 문장 구간(excerpts)을 추가로 받는다.
function tagSchema({ withExcerpt = false } = {}) {
  const properties = {
    existingTag: nullableString,
    name: { type: 'string' },
    category: { type: 'string', enum: CATEGORIES },
    description: nullableString,
    explanation: { type: 'string' },
    reason: { type: 'string' },
    similarExistingTags: { type: 'array', items: { type: 'string' } },
    ...(withExcerpt && { excerpts: { type: 'array', items: { type: 'string' } } }),
  };
  return { type: 'object', properties, required: Object.keys(properties), additionalProperties: false };
}

const ARTICLE_ANALYSIS_SCHEMA = {
  type: 'object',
  properties: {
    summary: { type: 'string' },
    commentary: nullableString,
    framing: nullableString,
    rhetoric: nullableString,
    stakeholders: nullableString,
    values: nullableString,
    tags: { type: 'array', items: tagSchema() },
  },
  required: ['summary', 'commentary', 'framing', 'rhetoric', 'stakeholders', 'values', 'tags'],
  additionalProperties: false,
};

const BOOK_ANALYSIS_SCHEMA = {
  type: 'object',
  properties: {
    summary: { type: 'string' },
    tags: { type: 'array', items: tagSchema({ withExcerpt: true }) },
  },
  required: ['summary', 'tags'],
  additionalProperties: false,
};

// 기존 태그 목록을 "T1. 아노미" 형식으로 만든다. 번호 → 태그 표도 함께 돌려준다.
function numberTags(existingTags) {
  const byRef = new Map();
  const lines = existingTags.map((tag, i) => {
    const ref = `T${i + 1}`;
    byRef.set(ref, tag);
    return `${ref}. ${tag.name}`;
  });
  return { byRef, text: lines.length ? lines.join('\n') : '(없음)' };
}

// Claude가 고른 번호를 실제 태그로 바꾼다. 목록에 없는 번호는 버린다.
function resolveRefs(raw, byRef) {
  return raw.tags.map(({ existingTag: ref, similarExistingTags, ...rest }) => {
    const existing = ref ? byRef.get(ref) : undefined;
    const similar = existing
      ? []
      : [...new Set(similarExistingTags)].map((r) => byRef.get(r)).filter(Boolean);
    return { ...rest, existingTag: existing ?? null, similarExisting: similar };
  });
}

// JSON 스키마를 지정해 Claude를 호출한다. what은 오류 문구용 ("기사", "책 구절")
// { data: 파싱한 결과, usage: { model, inputTokens, outputTokens, cacheWriteTokens, cacheReadTokens } }를 돌려준다 (비용 기록용)
async function requestJson({ model = MODEL, system, schema, content, what }) {
  let message;
  try {
    const stream = client.messages.stream({
      model,
      max_tokens: 8192,
      system,
      output_config: { format: { type: 'json_schema', schema } },
      messages: [{ role: 'user', content }],
    });
    message = await stream.finalMessage();
  } catch (err) {
    if (err instanceof Anthropic.RateLimitError) {
      throw httpError(503, '분석 요청이 많습니다. 잠시 후 다시 시도해주세요.');
    }
    if (err instanceof Anthropic.APIError) {
      console.error(`[Claude] API 오류 ${err.status}: ${err.message}`);
      throw httpError(502, `${what} 분석에 실패했습니다. 잠시 후 다시 시도해주세요.`);
    }
    throw err;
  }

  const cacheWrite = message.usage.cache_creation_input_tokens ?? 0;
  const cacheRead = message.usage.cache_read_input_tokens ?? 0;
  console.log(
    `[Claude] ${what} | 토큰 입력 ${message.usage.input_tokens} / 출력 ${message.usage.output_tokens}` +
      (cacheWrite || cacheRead ? ` / 캐시 쓰기 ${cacheWrite} · 읽기 ${cacheRead}` : '') +
      ` | stop: ${message.stop_reason}`
  );

  // inputTokens는 캐시를 뺀 나머지 입력이다
  const usage = {
    model,
    inputTokens: message.usage.input_tokens,
    outputTokens: message.usage.output_tokens,
    cacheWriteTokens: cacheWrite,
    cacheReadTokens: cacheRead,
  };
  // 응답이 잘리거나 결과를 못 쓰는 경우에도 비용은 청구되므로 먼저 잔액에서 뺀다
  creditService.recordUsageInBackground({ usage, what });

  if (message.stop_reason !== 'end_turn') {
    // max_tokens: 응답이 잘림, refusal: 스키마를 따르지 않았을 수 있음
    throw httpError(502, `${what} 분석 결과를 받지 못했습니다. 다시 시도해주세요.`);
  }
  const text = message.content.find((b) => b.type === 'text')?.text ?? '';
  try {
    return { data: JSON.parse(text), usage };
  } catch {
    throw httpError(502, `${what} 분석 결과를 읽을 수 없습니다. 다시 시도해주세요.`);
  }
}

// 기사를 분석해 요약·분석·태그 제안을 돌려준다.
// existingTags: 사용자의 기존 태그 [{ id, name }]. Claude가 같은 개념이면 이 중에서 고른다.
// 태그마다 existingTag(기존 태그 객체 또는 null)와 similarExisting(새 태그일 때 비슷한 기존 태그)이 붙는다.
// usage(토큰 사용량)도 함께 돌려준다.
async function analyzeArticleTags(articleText, existingTags = []) {
  const { byRef, text: tagList } = numberTags(existingTags);
  const { data: raw, usage } = await requestJson({
    system: ARTICLE_SYSTEM_PROMPT,
    schema: ARTICLE_ANALYSIS_SCHEMA,
    content: `기존 태그:\n${tagList}\n\n다음 뉴스 기사를 분석해주세요:\n\n${articleText}`,
    what: '기사',
  });
  return { ...raw, tags: resolveRefs(raw, byRef), usage };
}

// 책 페이지의 OCR 텍스트를 분석해 요약과 태그 제안(근거 문장 구간 excerpts 포함)을 돌려준다.
// 구간마다 OCR 텍스트에 그대로 있는지는 호출한 쪽에서 확인한다.
async function analyzeBookPage({ ocrText, bookTitle, author }, existingTags = []) {
  const { byRef, text: tagList } = numberTags(existingTags);
  const book = author ? `『${bookTitle}』 (${author})` : `『${bookTitle}』`;
  const { data: raw, usage } = await requestJson({
    system: BOOK_SYSTEM_PROMPT,
    schema: BOOK_ANALYSIS_SCHEMA,
    content: `기존 태그:\n${tagList}\n\n책: ${book}\n\n다음은 이 책 한 페이지의 OCR 텍스트입니다:\n\n${ocrText}`,
    what: '책 구절',
  });
  return { ...raw, tags: resolveRefs(raw, byRef), usage };
}

const SCORE_ITEMS = ['concept_fit', 'tag_naming', 'grounding', 'summary', 'reuse', 'excerpt_choice'];

const scoreSchema = {
  anyOf: [
    {
      type: 'object',
      properties: { score: { type: 'integer', enum: [1, 2, 3, 4, 5] }, reason: { type: 'string' } },
      required: ['score', 'reason'],
      additionalProperties: false,
    },
    { type: 'null' },
  ],
};

const JUDGE_SCHEMA = {
  type: 'object',
  properties: Object.fromEntries(SCORE_ITEMS.map((key) => [key, scoreSchema])),
  required: SCORE_ITEMS,
  additionalProperties: false,
};

// 분석 결과를 채점 기준표(rubric)대로 채점한다. 항목마다 { score, reason } 또는 null.
// source: 원문 (기사 본문 또는 OCR 텍스트), result: 사용자에게 돌려준 분석 결과 (요약·태그)
async function judgeAnalysis({ rubric, kind, source, existingTagNames, result }) {
  const kindName = kind === 'book' ? '책 페이지(OCR 텍스트)' : '뉴스 기사';
  const { data, usage } = await requestJson({
    model: JUDGE_MODEL,
    // 기준표는 매번 같으므로 캐시한다 (5분 안에 다시 채점하면 입력 단가의 1/10로 읽음)
    system: [
      {
        type: 'text',
        text: `당신은 사회학·철학 개념 태깅 결과를 채점하는 엄격한 채점자입니다. 아래 기준표만 따라 채점하고, 항목마다 점수와 한두 문장의 판단 근거를 씁니다. 근거에는 원문이나 결과의 구체적인 부분을 짚습니다.

${rubric}`,
        cache_control: { type: 'ephemeral' },
      },
    ],
    schema: JUDGE_SCHEMA,
    content: `분석 대상: ${kindName}

<원문>
${source}
</원문>

<기존 태그>
${existingTagNames.length ? existingTagNames.join(', ') : '(없음)'}
</기존 태그>

<분석 결과>
${JSON.stringify(result, null, 2)}
</분석 결과>`,
    what: '채점',
  });
  return { scores: data, usage };
}

module.exports = { client, analyzeArticleTags, analyzeBookPage, judgeAnalysis, CATEGORIES, SCORE_ITEMS, JUDGE_MODEL };
