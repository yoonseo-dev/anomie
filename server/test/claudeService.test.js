const { test, describe, afterEach, mock } = require('node:test');
const assert = require('node:assert/strict');
const Anthropic = require('@anthropic-ai/sdk');
const claudeService = require('../src/services/claudeService');

const existingTags = [
  { id: 'id-anomie', name: '아노미' },
  { id: 'id-stigma', name: '낙인 효과' },
];

const tag = (overrides) => ({
  existingTag: null,
  name: '위험사회',
  category: '사회학',
  description: '설명',
  explanation: '풀이',
  reason: '근거',
  similarExistingTags: [],
  ...overrides,
});

const message = (body, stop_reason = 'end_turn') => ({
  content: [{ type: 'text', text: typeof body === 'string' ? body : JSON.stringify(body) }],
  stop_reason,
  usage: { input_tokens: 1, output_tokens: 1 },
});

const output = (tags) => ({
  summary: '요약',
  commentary: null,
  framing: null,
  rhetoric: null,
  stakeholders: null,
  values: null,
  tags,
});

// Claude API 대신 정해 둔 응답을 돌려준다. 요청 내용은 stream.mock.calls로 확인한다.
function stubClaude(result) {
  return mock.method(claudeService.client.messages, 'stream', () => ({
    finalMessage: async () => {
      if (result instanceof Error) throw result;
      return result;
    },
  }));
}

describe('claudeService.analyzeArticleTags', () => {
  afterEach(() => mock.restoreAll());

  test('기존 태그를 번호로 넘기고 JSON 스키마 출력을 요청한다', async () => {
    const stream = stubClaude(message(output([])));

    await claudeService.analyzeArticleTags('제목: 기사', existingTags);

    const params = stream.mock.calls[0].arguments[0];
    assert.equal(params.output_config.format.type, 'json_schema');
    assert.match(params.messages[0].content, /T1\. 아노미\nT2\. 낙인 효과/);
    assert.doesNotMatch(params.messages[0].content, /id-anomie/); // 실제 ID는 보내지 않는다
  });

  test('번호 필드는 허용 번호(enum)로 묶어 Claude가 이름을 쓰지 못하게 한다', async () => {
    const stream = stubClaude(message(output([])));
    await claudeService.analyzeArticleTags('기사', existingTags);
    const tagItem = stream.mock.calls[0].arguments[0].output_config.format.schema.properties.tags.items;
    assert.deepEqual(tagItem.properties.existingTag.anyOf[0].enum, ['T1', 'T2']);
    assert.deepEqual(tagItem.properties.similarExistingTags.items.enum, ['T1', 'T2']);

    mock.restoreAll();
    const empty = stubClaude(message(output([])));
    await claudeService.analyzeArticleTags('기사', []);
    const emptyItem = empty.mock.calls[0].arguments[0].output_config.format.schema.properties.tags.items;
    assert.deepEqual(emptyItem.properties.existingTag, { type: 'null' }); // 기존 태그가 없으면 고를 수 없다
  });

  test('관계 제안 1·2단계도 개념·스크랩 번호를 enum으로 묶는다 (10-29: 이름·오타로 답해 후보가 전부 버려짐)', async () => {
    const s1 = stubClaude(message({ candidates: [] }));
    await claudeService.suggestRelationCandidates({
      tags: [
        { ref: 'T1', name: '판옵티콘', isNew: false },
        { ref: 'T2', name: '감시사회', isNew: true },
      ],
      excludedPairs: [],
      max: 8,
    });
    const s1Item = s1.mock.calls[0].arguments[0].output_config.format.schema.properties.candidates.items;
    assert.deepEqual(s1Item.properties.a.enum, ['T1', 'T2']);
    assert.match(s1.mock.calls[0].arguments[0].messages[0].content, /T2\. 감시사회 ★/);

    mock.restoreAll();
    const s2 = stubClaude(message({ relations: [] }));
    await claudeService.confirmRelations({
      candidates: [{ a: 'T2', b: 'T1', aName: '감시사회', bName: '판옵티콘' }],
      scraps: [{ ref: 'S1', text: '기사' }, { ref: 'S2', text: '책' }],
      max: 3,
    });
    const s2Item = s2.mock.calls[0].arguments[0].output_config.format.schema.properties.relations.items;
    assert.deepEqual(s2Item.properties.a.enum, ['T2', 'T1']);
    assert.deepEqual(s2Item.properties.evidence.items.enum, ['S1', 'S2']);
  });

  test('기존 태그가 없으면 "(없음)"으로 알린다', async () => {
    const stream = stubClaude(message(output([])));

    await claudeService.analyzeArticleTags('제목: 기사', []);

    assert.match(stream.mock.calls[0].arguments[0].messages[0].content, /기존 태그:\n\(없음\)/);
  });

  test('번호를 실제 태그로 바꾸고, 목록에 없는 번호는 버린다', async () => {
    stubClaude(
      message(
        output([
          tag({ existingTag: 'T1', name: '아노미', description: null, similarExistingTags: ['T2'] }),
          tag({ similarExistingTags: ['T2', 'T9', 'T2'] }),
          tag({ existingTag: 'T9', name: '소외' }),
        ])
      )
    );

    const result = await claudeService.analyzeArticleTags('제목: 기사', existingTags);

    const [reused, created, unknownRef] = result.tags;
    assert.deepEqual(reused.existingTag, existingTags[0]);
    assert.deepEqual(reused.similarExisting, []); // 기존 태그를 골랐으면 비슷한 태그는 필요 없다
    assert.equal(created.existingTag, null);
    assert.deepEqual(created.similarExisting, [existingTags[1]]);
    assert.equal(unknownRef.existingTag, null); // 지어낸 번호는 새 태그로 취급
    assert.equal(unknownRef.name, '소외');
    assert.equal(result.summary, '요약');
  });

  test('응답이 잘리거나(max_tokens) JSON이 깨지면 502', async () => {
    stubClaude(message(output([]), 'max_tokens'));
    await assert.rejects(claudeService.analyzeArticleTags('기사', []), { status: 502 });

    mock.restoreAll();
    stubClaude(message('{ 깨진 json'));
    await assert.rejects(claudeService.analyzeArticleTags('기사', []), { status: 502 });
  });

  test('책 분석은 OCR 텍스트와 책 정보를 넘기고, 태그마다 근거 문장(excerpt)을 받는다', async () => {
    const stream = stubClaude(
      message({
        summary: '요약',
        tags: [tag({ existingTag: 'T1', name: '아노미', excerpts: ['규범이 느슨해질 때'] })],
      })
    );

    const result = await claudeService.analyzeBookPage(
      { ocrText: '규범이 느슨해질 때\n욕망은', bookTitle: '자살론', author: '에밀 뒤르켐' },
      existingTags
    );

    const params = stream.mock.calls[0].arguments[0];
    const tagItem = params.output_config.format.schema.properties.tags.items;
    assert.ok(tagItem.required.includes('excerpts'));
    assert.equal(tagItem.properties.excerpts.type, 'array');
    assert.match(params.messages[0].content, /책: 『자살론』 \(에밀 뒤르켐\)/);
    assert.match(params.messages[0].content, /규범이 느슨해질 때\n욕망은/);
    assert.deepEqual(result.tags[0].existingTag, existingTags[0]);
    assert.deepEqual(result.tags[0].excerpts, ['규범이 느슨해질 때']);
  });

  test('기사 분석 스키마에는 근거 문장이 없다', async () => {
    const stream = stubClaude(message(output([])));

    await claudeService.analyzeArticleTags('기사', []);

    const tagItem = stream.mock.calls[0].arguments[0].output_config.format.schema.properties.tags.items;
    assert.ok(!('excerpts' in tagItem.properties));
  });

  test('분석 결과에 토큰 사용량(usage)을 함께 돌려준다', async () => {
    stubClaude({ ...message(output([])), usage: { input_tokens: 1200, output_tokens: 300 } });

    const result = await claudeService.analyzeArticleTags('기사', []);

    assert.deepEqual(result.usage, {
      model: 'claude-haiku-4-5-20251001',
      inputTokens: 1200,
      outputTokens: 300,
      cacheWriteTokens: 0,
      cacheReadTokens: 0,
    });
  });

  test('채점은 기준표를 시스템 프롬프트에 넣고, 항목별 { score, reason } 또는 null을 받는다', async () => {
    const scores = {
      concept_fit: { score: 4, reason: '근거' },
      tag_naming: { score: 5, reason: '근거' },
      grounding: { score: 4, reason: '근거' },
      summary: { score: 5, reason: '근거' },
      reuse: null,
      excerpt_choice: { score: 3, reason: '근거' },
    };
    const stream = stubClaude({
      ...message(scores),
      usage: { input_tokens: 900, output_tokens: 400, cache_creation_input_tokens: 0, cache_read_input_tokens: 2800 },
    });

    const judged = await claudeService.judgeAnalysis({
      rubric: '# 기준표 본문',
      kind: 'book',
      source: 'OCR 원문',
      existingTagNames: ['아노미'],
      result: { summary: '요약', tags: [] },
    });

    const params = stream.mock.calls[0].arguments[0];
    assert.equal(params.model, claudeService.JUDGE_MODEL);
    // 기준표는 캐시 대상, 원문·결과는 매번 바뀌므로 캐시 뒤(user 메시지)에 둔다
    assert.match(params.system[0].text, /# 기준표 본문/);
    assert.deepEqual(params.system[0].cache_control, { type: 'ephemeral' });
    assert.match(params.messages[0].content, /<원문>\nOCR 원문\n<\/원문>/);
    assert.match(params.messages[0].content, /<기존 태그>\n아노미\n/);
    assert.deepEqual(Object.keys(params.output_config.format.schema.properties), claudeService.SCORE_ITEMS);
    assert.deepEqual(judged.scores, scores);
    assert.equal(judged.usage.model, claudeService.JUDGE_MODEL);
    assert.equal(judged.usage.cacheReadTokens, 2800);
  });

  test('API 한도 초과는 503, 그 밖의 API 오류는 502', async () => {
    const headers = new Headers();
    stubClaude(new Anthropic.RateLimitError(429, {}, 'rate limited', headers));
    await assert.rejects(claudeService.analyzeArticleTags('기사', []), { status: 503 });

    mock.restoreAll();
    stubClaude(new Anthropic.InternalServerError(500, {}, 'boom', headers));
    await assert.rejects(claudeService.analyzeArticleTags('기사', []), { status: 502 });
  });
});
