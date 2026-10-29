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
        tags: [tag({ existingTag: 'T1', name: '아노미', excerpt: '규범이 느슨해질 때' })],
      })
    );

    const result = await claudeService.analyzeBookPage(
      { ocrText: '규범이 느슨해질 때\n욕망은', bookTitle: '자살론', author: '에밀 뒤르켐' },
      existingTags
    );

    const params = stream.mock.calls[0].arguments[0];
    const tagItem = params.output_config.format.schema.properties.tags.items;
    assert.ok(tagItem.required.includes('excerpt'));
    assert.match(params.messages[0].content, /책: 『자살론』 \(에밀 뒤르켐\)/);
    assert.match(params.messages[0].content, /규범이 느슨해질 때\n욕망은/);
    assert.deepEqual(result.tags[0].existingTag, existingTags[0]);
    assert.equal(result.tags[0].excerpt, '규범이 느슨해질 때');
  });

  test('기사 분석 스키마에는 근거 문장이 없다', async () => {
    const stream = stubClaude(message(output([])));

    await claudeService.analyzeArticleTags('기사', []);

    const tagItem = stream.mock.calls[0].arguments[0].output_config.format.schema.properties.tags.items;
    assert.ok(!('excerpt' in tagItem.properties));
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
