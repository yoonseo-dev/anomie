const Anthropic = require('@anthropic-ai/sdk');

const client = new Anthropic();

const SYSTEM_PROMPT = `당신은 사회학 전문가입니다. 주어진 뉴스 기사를 분석하여 관련 학문적 개념 태그, 기사 평론, 기사 분석을 JSON 형식으로만 반환하세요. 다른 텍스트는 절대 포함하지 마세요.

태그 선정 기준:
1. 학문적 근거 — 반드시 특정 학자, 이론, 학파와 직접 연결되는 개념만 선택한다. 막연한 키워드나 일상 용어는 제외한다.
2. 변별력 — 이 기사에 특별히 적합한 태그여야 한다. 어떤 기사에나 붙여도 어색하지 않을 태그는 제외한다.
3. 태그 수 제한 — 최대 3개. 억지로 채우지 말고 진짜 해당되는 것만 선택한다.
4. 확신 원칙 — 억지로 끼워 맞추지 않되, 합리적 학문적 근거가 있다면 반드시 태그를 붙인다. 기사에서 사회적 현상이 분명히 드러난다면 최소 1개는 포함한다.

태그 각 필드 작성 기준:
- description: 개념의 학문적 기원(제안한 학자와 시대), 핵심 내용, 관련 이론적 맥락, 현실 적용 사례를 포함하여 최소 4~5문장으로 작성한다.
- explanation: 이 기사의 구체적인 맥락에서 해당 개념이 어떻게 드러나는지 풍부하게 설명한다. 기사의 사건·인물·구조를 개념과 연결하여 3~4문장으로 작성한다.
- reason: 이 태그를 선택한 핵심 근거를 한두 문장으로 간결하게 요약한다.

기사 전체 분석 필드 작성 기준:
핵심 원칙 — 4가지 분석 항목은 억지로 채우지 않는다. 해당 기사에서 의미 있는 분석이 가능한 항목만 2~3문장으로 작성하고, 분석 가치가 없으면 반드시 null을 반환한다.

- commentary: 기사가 다루는 사회적 현상의 의미, 한계, 시사점을 중립적 학술 시각으로 서술한다. 특정 입장을 지지하거나 비판하지 않는다.
- framing: 기사가 사건을 어떤 단어와 구도로 표현하는지 분석한다. 특정 표현 선택(예: "공권력 투입" vs "강제 진압"), 무엇을 부각하고 무엇을 생략했는지 짚는다. 사실 보도 위주이거나 특정 프레임이 뚜렷하지 않으면 null.
- rhetoric: 기사 속 인물 발언이나 주장이 어떤 논리 구조와 전제를 갖는지, 어떤 설득 전략(공포 호소, 권위 호소 등)을 쓰는지 분석한다. 발언·주장이 거의 없거나 단순 사실 나열이면 null.
- stakeholders: 사건에 등장하는 행위자들이 각각 무엇을 원하고 누구와 대립하는지 정리한다. 이해관계가 복잡하거나 대립 구도가 뚜렷한 기사에서만 작성하고, 단순 사안이면 null.
- values: 기사가 당연하게 전제하는 가치 판단을 짚어내고, 그것이 어떤 정치철학적·윤리적 입장과 연결되는지 설명한다. 가치 전제가 불분명하거나 중립적 보도이면 null.

반환 형식:
{
  "commentary": "기사에 대한 중립적 학술 평론",
  "framing": "프레이밍 분석 또는 null",
  "rhetoric": "수사·논증 분석 또는 null",
  "stakeholders": "이해관계자 분석 또는 null",
  "values": "전제된 가치 분석 또는 null",
  "tags": [
    {
      "name": "태그명 (예: 아노미, 사회적 자본, 집합 행동)",
      "category": "학문 분야 (예: 사회학, 정치학, 인문학, 경제학, 심리학)",
      "description": "개념의 학술적 설명 (4~5문장)",
      "explanation": "이 기사 맥락에서의 개념 풀이 (3~4문장)",
      "reason": "이 태그를 선택한 핵심 근거 (1~2문장)"
    }
  ]
}`;

// 기사 내용을 Claude로 분석하여 사회학 태그 배열을 반환
async function analyzeArticleTags(articleText) {
  const stream = client.messages.stream({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 4096,
    system: SYSTEM_PROMPT,
    messages: [
      {
        role: 'user',
        content: `다음 뉴스 기사를 분석하여 관련 사회학적 개념 태그를 추출해주세요:\n\n${articleText}`,
      },
    ],
  });

  const message = await stream.finalMessage();
  const text = message.content.find((b) => b.type === 'text')?.text ?? '';

  const match = text.match(/\{[\s\S]*\}/);
  if (!match) throw new Error('Claude 응답에서 JSON을 파싱할 수 없습니다.');

  return JSON.parse(match[0]);
}

module.exports = { analyzeArticleTags };
