const Anthropic = require('@anthropic-ai/sdk');
const httpError = require('../utils/httpError');
const creditService = require('./creditService');

const client = new Anthropic();

const MODEL = 'claude-haiku-4-5-20251001';

// 기사·책 분석 모델. 학술 용어를 정확히 고르도록 상위 모델을 쓴다 (11-01, Haiku 4.5에서 변경.
// Opus 5.5는 책 1장 약 90원이라 비용 때문에 Sonnet 5.5로). 관계 제안은 그대로 MODEL을 쓴다.
const ANALYSIS_MODEL = 'claude-sonnet-5-5';

// 모델별 호출 설정. Sonnet 5.5는 생각(thinking)이 기본으로 켜져 있고 깊이는 effort로 정한다
// (이 모델의 기본은 high지만, 개념 고르기는 medium으로 충분하고 생각 토큰 비용을 줄인다).
// 생각에 쓰는 토큰도 출력에 들어가므로 max_tokens를 넉넉히 둔다.
// fallback: 안전 분류기가 거절하면 서버가 권장 모델로 다시 돌린다 (beta server-side-fallback-2026-07-01).
const MODEL_OPTIONS = {
  [ANALYSIS_MODEL]: { effort: 'medium', maxTokens: 16000, fallback: true },
};
// 채점용 모델. 기준표(약 2,800토큰)를 프롬프트 캐시에 올리려면 최소 길이가 512토큰인 모델이어야 한다
// (Haiku 4.5는 4,096토큰 미만이면 캐시되지 않음). 단가도 Haiku 4.5의 1/10 (10-29)
const JUDGE_MODEL = 'claude-haiku-5-5';

// Tag.category에 저장하는 고정 분야 목록. 목록 밖이면 "기타" (doc/plan.md 3장)
const CATEGORIES = ['사회학', '철학', '정치학', '경제학', '심리학', '인류학', '커뮤니케이션학', '기타'];

// 기사·책 공통 태그 기준. source는 "기사" 또는 "책 구절"
const tagRules = (source) => `태그 고르는 순서:
1. 먼저 기존 태그 목록은 보지 말고 ${source} 원문만 읽고, 원문에 드러난 핵심 개념을 중요한 순서로 고른다.
2. 그다음 고른 개념마다 같은 개념의 기존 태그가 있는지 확인한다 (아래 "기존 태그 재사용").
기존 태그 목록에 있다는 이유만으로 태그를 고르지 않는다. 원문의 핵심이 아닌 기존 태그를 넣느라 원문의 핵심 개념을 빼면 안 된다.

태그 선정 기준:
1. 학문적 근거 — 반드시 특정 학자, 이론, 학파와 직접 연결되는 개념만 선택한다. 막연한 키워드나 일상 용어는 제외한다.
2. 변별력 — 이 ${source}에 특별히 적합한 태그여야 한다. 어떤 글에나 붙여도 어색하지 않을 태그는 제외한다.
3. 태그 수 — 1~3개. 억지로 늘리지 말고 진짜 해당되는 것만 선택하되, 학자와 바로 이어지는 개념이 없어 보여도 글에 드러난 사회 현상에 가장 가까운 학술 개념을 최소 1개는 고른다 (태그가 없으면 사용자가 스크랩을 저장할 수 없다).
4. 태그 이름 — 학계와 교과서에서 실제로 쓰는 학술 용어를 그대로 쓴다 (보통 2~8자). 다른 글에도 그대로 붙일 수 있는 이름이어야 다른 스크랩과 연결된다.
   - 원문이 학술 개념어를 직접 쓰면(예: "염세주의", "소외") 그 용어를 우선한다.
   - 개념을 풀어 쓴 설명형 이름, 두 개념을 "A와 B"로 묶은 이름, 원문 표현을 조합해 새로 만든 이름은 쓰지 않는다. 두 개념이 모두 중요하면 태그를 둘로 나눈다.
   - 좋은 예: 아노미, 지위 불안, 인정 투쟁, 상대적 박탈감, 낙인 효과, 사회적 자본, 자유주의, 소외, 염세주의
   - 나쁜 예 → 바른 이름: "인간의 자유화" → 자유주의, "불안과 지위 경쟁" → 지위 불안, "염세주의적 거리두기" → 염세주의, "노동과 소비의 모순" → 소외, "사회적 지위의 조건부 인정" → 조건부 인정
   - 정확히 맞는 학술 용어가 정말 없을 때만 짧은 설명형 이름을 쓰고, reason에 통용되는 용어가 없어서 그렇게 지었다고 밝힌다.
5. 확신 원칙 — 억지로 끼워 맞추지 않되, 합리적 학문적 근거가 있다면 반드시 태그를 붙인다. ${source}에서 사회적 현상이나 개념이 분명히 드러난다면 최소 1개는 포함한다.

사용자의 기존 태그 재사용:
- 사용자 메시지에 "기존 태그" 목록이 번호(T1, T2 …)와 함께 주어진다.
- 원문에서 고른 개념이 기존 태그와 같은 개념이면(표기·띄어쓰기·동의어가 달라도) 반드시 그 번호를 existingTag에 넣는다. 이때 name에는 기존 태그 이름을 그대로 쓰고 description은 null로 둔다. 관련만 있고 같은 개념이 아니면 재사용하지 않는다.
- 기존 태그 중 같은 개념이 없을 때만 existingTag를 null로 두고 새 태그 이름을 name에 쓴다.
- 새 태그일 때 similarExistingTags에는 사용자가 대신 고를 만한 비슷한 기존 태그 번호를 최대 3개 넣는다. 없거나 기존 태그를 재사용했으면 빈 배열로 둔다.
- 목록에 없는 번호는 절대 쓰지 않는다.

태그 각 필드 작성 기준:
- category: 다음 중 하나 — ${CATEGORIES.join(', ')}. 어디에도 맞지 않으면 "기타".
- description: (새 태그만) 개념의 학문적 기원(제안한 학자와 시대), 핵심 내용, 관련 이론적 맥락을 3~4문장으로 작성한다. 확실하지 않은 학자 이름이나 연도는 쓰지 않는다.
- explanation: 이 ${source}의 구체적인 맥락에서 해당 개념이 어떻게 드러나는지 3~4문장으로 설명한다. ${source}의 구체적인 사실·주장·표현을 짚어 개념과 잇되, 원문에 없는 사건·배경·시대 맥락을 이 글의 내용처럼 단정하지 않는다 (학자·이론의 배경은 description에 쓴다). 이 규칙은 풀이를 쓰는 방법이지, 원문에 그 개념어가 직접 나오지 않는다고 태그를 빼라는 뜻이 아니다.
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

// 번호 필드는 허용 번호를 enum으로 묶는다. 그러지 않으면 Claude가 번호 대신 개념 이름을 쓰기도 한다 (10-29 실측)
const refString = (refs) => (refs.length ? { type: 'string', enum: refs } : { type: 'string' });

// 태그 하나의 스키마. refs: 기존 태그 번호 목록. 책은 근거 문장 구간(excerpts)을 추가로 받는다.
function tagSchema({ refs, withExcerpt = false }) {
  const properties = {
    existingTag: refs.length ? { anyOf: [refString(refs), { type: 'null' }] } : { type: 'null' },
    name: { type: 'string' },
    category: { type: 'string', enum: CATEGORIES },
    description: nullableString,
    explanation: { type: 'string' },
    reason: { type: 'string' },
    similarExistingTags: { type: 'array', items: refString(refs) },
    ...(withExcerpt && { excerpts: { type: 'array', items: { type: 'string' } } }),
  };
  return { type: 'object', properties, required: Object.keys(properties), additionalProperties: false };
}

const articleAnalysisSchema = (refs) => ({
  type: 'object',
  properties: {
    summary: { type: 'string' },
    commentary: nullableString,
    framing: nullableString,
    rhetoric: nullableString,
    stakeholders: nullableString,
    values: nullableString,
    tags: { type: 'array', items: tagSchema({ refs }), minItems: 1 },
  },
  required: ['summary', 'commentary', 'framing', 'rhetoric', 'stakeholders', 'values', 'tags'],
  additionalProperties: false,
});

const bookAnalysisSchema = (refs) => ({
  type: 'object',
  properties: {
    summary: { type: 'string' },
    tags: { type: 'array', items: tagSchema({ refs, withExcerpt: true }), minItems: 1 },
  },
  required: ['summary', 'tags'],
  additionalProperties: false,
});

// 기존 태그 목록을 "T1. 아노미" 형식으로 만든다. 번호 → 태그 표도 함께 돌려준다.
function numberTags(existingTags) {
  const byRef = new Map();
  const lines = existingTags.map((tag, i) => {
    const ref = `T${i + 1}`;
    byRef.set(ref, tag);
    return `${ref}. ${tag.name}`;
  });
  return { byRef, refs: [...byRef.keys()], text: lines.length ? lines.join('\n') : '(없음)' };
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
  const options = MODEL_OPTIONS[model] ?? {};
  const params = {
    model,
    max_tokens: options.maxTokens ?? 8192,
    system,
    output_config: {
      format: { type: 'json_schema', schema },
      ...(options.effort && { effort: options.effort }),
    },
    messages: [{ role: 'user', content }],
  };
  let message;
  try {
    const stream = options.fallback
      ? client.beta.messages.stream({ ...params, betas: ['server-side-fallback-2026-07-01'], fallbacks: 'default' })
      : client.messages.stream(params);
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

  // 비용은 요청한 모델 단가로 기록한다 (드물게 거절 → 다른 모델로 다시 돈 경우는 로그로만 남긴다)
  if ((message.usage.iterations ?? []).some((i) => i.type === 'fallback_message')) {
    console.log(`[Claude] ${what} | 거절되어 다른 모델(${message.model})로 다시 분석함`);
  }
  if (message.stop_reason === 'refusal') {
    console.error(`[Claude] ${what} | 거절: ${message.stop_details?.category ?? '분류 없음'}`);
  }
  if (message.stop_reason !== 'end_turn') {
    // max_tokens: 응답이 잘림, refusal: 안전 분류기가 거절(대체 모델까지)
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
  const { byRef, refs, text: tagList } = numberTags(existingTags);
  const { data: raw, usage } = await requestJson({
    model: ANALYSIS_MODEL,
    system: ARTICLE_SYSTEM_PROMPT,
    schema: articleAnalysisSchema(refs),
    content: `기존 태그:\n${tagList}\n\n다음 뉴스 기사를 분석해주세요:\n\n${articleText}`,
    what: '기사',
  });
  return { ...raw, tags: resolveRefs(raw, byRef), usage };
}

// 책 페이지의 OCR 텍스트를 분석해 요약과 태그 제안(근거 문장 구간 excerpts 포함)을 돌려준다.
// 구간마다 OCR 텍스트에 그대로 있는지는 호출한 쪽에서 확인한다.
async function analyzeBookPage({ ocrText, bookTitle, author }, existingTags = []) {
  const { byRef, refs, text: tagList } = numberTags(existingTags);
  const book = author ? `『${bookTitle}』 (${author})` : `『${bookTitle}』`;
  const { data: raw, usage } = await requestJson({
    model: ANALYSIS_MODEL,
    system: BOOK_SYSTEM_PROMPT,
    schema: bookAnalysisSchema(refs),
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

// ----- 관계 제안 (2단계, doc/plan.md 1-3·7장) -----

const relationCandidateSchema = (refs) => ({
  type: 'object',
  properties: {
    candidates: {
      type: 'array',
      items: {
        type: 'object',
        properties: { a: refString(refs), b: refString(refs) },
        required: ['a', 'b'],
        additionalProperties: false,
      },
    },
  },
  required: ['candidates'],
  additionalProperties: false,
});

// 1단계 (저렴): 개념 이름만 보고 연결 후보 쌍을 고른다. 근거 확인은 2단계에서 한다.
// tags: [{ ref, name, isNew }] (isNew: 방금 저장한 스크랩에 붙은 태그), excludedPairs: ["T1|T3", ...] 이미 관계가 있는 쌍
async function suggestRelationCandidates({ tags, excludedPairs, max }) {
  const { data, usage } = await requestJson({
    system: `당신은 사회학·철학 개념 사이의 연결 후보를 고르는 전문가입니다. 사용자가 방금 저장한 스크랩의 개념(★ 표시)과 사용자의 다른 개념 사이에서, 실제 글 속에서 함께 작동했을 가능성이 있는 쌍을 고르세요.

- 각 쌍의 한쪽은 반드시 ★ 개념이다. ★ 개념끼리의 쌍도 된다.
- 여기서는 후보만 고른다. 다음 단계에서 사용자의 스크랩 내용으로 근거를 확인하므로, 가능성이 있으면 넉넉히 고르되 최대 ${max}쌍.
- 이름만 비슷하거나 같은 분야라는 이유만으로는 고르지 않는다. 한 현상의 원인·결과·사례·대비처럼 내용으로 이어질 수 있는 쌍을 고른다.
- a, b에는 개념 이름이 아니라 번호(T1, T2 …)만 쓴다. "제외할 쌍"과 같은 쌍(순서 무관)은 고르지 않는다.`,
    schema: relationCandidateSchema(tags.map((t) => t.ref)),
    content: `개념 목록 (★ = 방금 저장한 스크랩의 개념):
${tags.map((t) => `${t.ref}. ${t.name}${t.isNew ? ' ★' : ''}`).join('\n')}

제외할 쌍:
${excludedPairs.length ? excludedPairs.join(', ') : '(없음)'}`,
    what: '관계 후보',
  });
  return { candidates: data.candidates, usage };
}

const relationConfirmSchema = (tagRefs, scrapRefs) => ({
  type: 'object',
  properties: {
    relations: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          a: refString(tagRefs),
          b: refString(tagRefs),
          reason: { type: 'string' },
          evidence: { type: 'array', items: refString(scrapRefs) },
        },
        required: ['a', 'b', 'reason', 'evidence'],
        additionalProperties: false,
      },
    },
  },
  required: ['relations'],
  additionalProperties: false,
});

// 2단계 (상세): 후보 쌍마다 사용자의 스크랩에 근거가 있는지 확인하고, 근거가 있는 쌍만 관계로 제안한다.
// candidates: [{ a, b, aName, bName }], scraps: [{ ref, text }] (요약·태그 이유·근거 문장을 정리한 글)
async function confirmRelations({ candidates, scraps, max }) {
  const { data, usage } = await requestJson({
    system: `당신은 사용자의 스크랩을 근거로 사회학·철학 개념 사이의 관계를 제안하는 전문가입니다.

관계 제안 기준 (스크랩 근거 필수):
- 사용자의 스크랩에서 두 개념이 함께 작동한 근거가 있을 때만 제안한다. 한 스크랩 안의 근거도, 서로 다른 스크랩(예: 책의 이론과 뉴스의 현실)에 걸친 근거도 된다.
- 교과서에서 유명한 짝이라도 이 스크랩들에서 이어지는 내용이 없으면 제안하지 않는다. 학자 이름이나 이론을 지어내지 않는다.
- 근거가 약하면 제안하지 않는다. 제안이 0개여도 된다. 최대 ${max}개, 근거가 강한 순서로.

필드 작성 기준:
- a, b: 후보 쌍의 개념 번호 그대로.
- evidence: 근거가 되는 스크랩 번호(S1, S2 …). 두 개념이 각각 실제로 붙어 있는 스크랩이어야 한다.
- reason: 두 개념이 어떻게 이어지는지 2~3문장. 근거 스크랩의 구체적인 내용을 각각 언급한다 (예: "『감시와 처벌』의 판옵티콘 설명처럼, 배달 앱이 라이더의 위치를 실시간으로 보는 기사에서 …").
  사용자에게 그대로 보이는 문장이므로 S1·T1 같은 번호는 쓰지 말고, 책 제목·기사 제목이나 내용으로 가리킨다.`,
    schema: relationConfirmSchema(
      [...new Set(candidates.flatMap((c) => [c.a, c.b]))],
      scraps.map((s) => s.ref)
    ),
    content: `후보 쌍:
${candidates.map((c) => `- ${c.a}(${c.aName}) — ${c.b}(${c.bName})`).join('\n')}

사용자의 스크랩:
${scraps.map((s) => `[${s.ref}] ${s.text}`).join('\n\n')}`,
    what: '관계 근거 확인',
  });
  return { relations: data.relations, usage };
}

module.exports = {
  client,
  analyzeArticleTags,
  analyzeBookPage,
  judgeAnalysis,
  suggestRelationCandidates,
  confirmRelations,
  CATEGORIES,
  SCORE_ITEMS,
  JUDGE_MODEL,
  ANALYSIS_MODEL,
};
