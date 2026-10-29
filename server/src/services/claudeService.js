const Anthropic = require('@anthropic-ai/sdk');
const httpError = require('../utils/httpError');

const client = new Anthropic();

const MODEL = 'claude-haiku-4-5-20251001';

// Tag.category에 저장하는 고정 분야 목록. 목록 밖이면 "기타" (doc/plan.md 3장)
const CATEGORIES = ['사회학', '철학', '정치학', '경제학', '심리학', '인류학', '커뮤니케이션학', '기타'];

const SYSTEM_PROMPT = `당신은 사회학 전문가입니다. 주어진 뉴스 기사를 분석하여 관련 학문적 개념 태그, 기사 요약, 기사 평론, 기사 분석을 지정된 JSON 형식으로 반환하세요.

태그 선정 기준:
1. 학문적 근거 — 반드시 특정 학자, 이론, 학파와 직접 연결되는 개념만 선택한다. 막연한 키워드나 일상 용어는 제외한다.
2. 변별력 — 이 기사에 특별히 적합한 태그여야 한다. 어떤 기사에나 붙여도 어색하지 않을 태그는 제외한다.
3. 태그 수 제한 — 최대 3개. 억지로 채우지 말고 진짜 해당되는 것만 선택한다.
4. 확신 원칙 — 억지로 끼워 맞추지 않되, 합리적 학문적 근거가 있다면 반드시 태그를 붙인다. 기사에서 사회적 현상이 분명히 드러난다면 최소 1개는 포함한다.

사용자의 기존 태그 재사용:
- 사용자 메시지에 "기존 태그" 목록이 번호(T1, T2 …)와 함께 주어진다.
- 고른 개념이 기존 태그와 같은 개념이면(표기·띄어쓰기·동의어가 달라도) 반드시 그 번호를 existingTag에 넣는다. 이때 name에는 기존 태그 이름을 그대로 쓰고 description은 null로 둔다.
- 기존 태그 중 같은 개념이 없을 때만 existingTag를 null로 두고 새 태그 이름을 name에 쓴다.
- 새 태그일 때 similarExistingTags에는 사용자가 대신 고를 만한 비슷한 기존 태그 번호를 최대 3개 넣는다. 없거나 기존 태그를 재사용했으면 빈 배열로 둔다.
- 목록에 없는 번호는 절대 쓰지 않는다.

태그 각 필드 작성 기준:
- category: 다음 중 하나 — ${CATEGORIES.join(', ')}. 어디에도 맞지 않으면 "기타".
- description: (새 태그만) 개념의 학문적 기원(제안한 학자와 시대), 핵심 내용, 관련 이론적 맥락을 3~4문장으로 작성한다. 확실하지 않은 학자 이름이나 연도는 쓰지 않는다.
- explanation: 이 기사의 구체적인 맥락에서 해당 개념이 어떻게 드러나는지 설명한다. 기사의 사건·인물·구조를 개념과 연결하여 3~4문장으로 작성한다.
- reason: 이 태그를 선택한 핵심 근거를 한두 문장으로 간결하게 요약한다.

기사 필드 작성 기준:
- summary: 기사의 핵심 사실과 쟁점을 2~3문장으로 요약한다. 나중에 원문 대신 이 요약만 보고 다른 스크랩과의 개념 연결을 판단하므로, 누가·무엇을·왜가 드러나게 쓴다.
- 아래 4가지 분석 항목은 억지로 채우지 않는다. 의미 있는 분석이 가능한 항목만 2~3문장으로 작성하고, 분석 가치가 없으면 반드시 null을 반환한다.
- commentary: 기사가 다루는 사회적 현상의 의미, 한계, 시사점을 중립적 학술 시각으로 서술한다. 특정 입장을 지지하거나 비판하지 않는다.
- framing: 기사가 사건을 어떤 단어와 구도로 표현하는지 분석한다. 특정 표현 선택(예: "공권력 투입" vs "강제 진압"), 무엇을 부각하고 무엇을 생략했는지 짚는다. 사실 보도 위주이거나 특정 프레임이 뚜렷하지 않으면 null.
- rhetoric: 기사 속 인물 발언이나 주장이 어떤 논리 구조와 전제를 갖는지, 어떤 설득 전략(공포 호소, 권위 호소 등)을 쓰는지 분석한다. 발언·주장이 거의 없거나 단순 사실 나열이면 null.
- stakeholders: 사건에 등장하는 행위자들이 각각 무엇을 원하고 누구와 대립하는지 정리한다. 이해관계가 복잡하거나 대립 구도가 뚜렷한 기사에서만 작성하고, 단순 사안이면 null.
- values: 기사가 당연하게 전제하는 가치 판단을 짚어내고, 그것이 어떤 정치철학적·윤리적 입장과 연결되는지 설명한다. 가치 전제가 불분명하거나 중립적 보도이면 null.`;

const nullableString = { anyOf: [{ type: 'string' }, { type: 'null' }] };

const ARTICLE_ANALYSIS_SCHEMA = {
  type: 'object',
  properties: {
    summary: { type: 'string' },
    commentary: nullableString,
    framing: nullableString,
    rhetoric: nullableString,
    stakeholders: nullableString,
    values: nullableString,
    tags: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          existingTag: nullableString,
          name: { type: 'string' },
          category: { type: 'string', enum: CATEGORIES },
          description: nullableString,
          explanation: { type: 'string' },
          reason: { type: 'string' },
          similarExistingTags: { type: 'array', items: { type: 'string' } },
        },
        required: ['existingTag', 'name', 'category', 'description', 'explanation', 'reason', 'similarExistingTags'],
        additionalProperties: false,
      },
    },
  },
  required: ['summary', 'commentary', 'framing', 'rhetoric', 'stakeholders', 'values', 'tags'],
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
  return raw.tags.map((t) => {
    const existing = t.existingTag ? byRef.get(t.existingTag) : undefined;
    const similar = existing
      ? []
      : [...new Set(t.similarExistingTags)].map((ref) => byRef.get(ref)).filter(Boolean);
    return {
      existingTag: existing ?? null,
      name: t.name,
      category: t.category,
      description: t.description,
      explanation: t.explanation,
      reason: t.reason,
      similarExisting: similar,
    };
  });
}

// 기사를 분석해 요약·분석·태그 제안을 돌려준다.
// existingTags: 사용자의 기존 태그 [{ id, name }]. Claude가 같은 개념이면 이 중에서 고른다.
// 태그마다 existingTag(기존 태그 객체 또는 null)와 similarExisting(새 태그일 때 비슷한 기존 태그)이 붙는다.
async function analyzeArticleTags(articleText, existingTags = []) {
  const { byRef, text: tagList } = numberTags(existingTags);

  let message;
  try {
    const stream = client.messages.stream({
      model: MODEL,
      max_tokens: 8192,
      system: SYSTEM_PROMPT,
      output_config: { format: { type: 'json_schema', schema: ARTICLE_ANALYSIS_SCHEMA } },
      messages: [
        {
          role: 'user',
          content: `기존 태그:\n${tagList}\n\n다음 뉴스 기사를 분석해주세요:\n\n${articleText}`,
        },
      ],
    });
    message = await stream.finalMessage();
  } catch (err) {
    if (err instanceof Anthropic.RateLimitError) {
      throw httpError(503, '분석 요청이 많습니다. 잠시 후 다시 시도해주세요.');
    }
    if (err instanceof Anthropic.APIError) {
      console.error(`[Claude] API 오류 ${err.status}: ${err.message}`);
      throw httpError(502, '기사 분석에 실패했습니다. 잠시 후 다시 시도해주세요.');
    }
    throw err;
  }

  console.log(
    `[Claude] 토큰 입력 ${message.usage.input_tokens} / 출력 ${message.usage.output_tokens} | stop: ${message.stop_reason}`
  );
  if (message.stop_reason !== 'end_turn') {
    // max_tokens: 응답이 잘림, refusal: 스키마를 따르지 않았을 수 있음
    throw httpError(502, '기사 분석 결과를 받지 못했습니다. 다시 시도해주세요.');
  }

  const text = message.content.find((b) => b.type === 'text')?.text ?? '';
  let raw;
  try {
    raw = JSON.parse(text);
  } catch {
    throw httpError(502, '기사 분석 결과를 읽을 수 없습니다. 다시 시도해주세요.');
  }

  return { ...raw, tags: resolveRefs(raw, byRef) };
}

module.exports = { client, analyzeArticleTags, CATEGORIES };
