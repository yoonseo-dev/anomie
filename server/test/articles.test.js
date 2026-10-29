const { test, describe, before, after, afterEach, mock } = require('node:test');
const assert = require('node:assert/strict');
const { prisma, startServer, createTestUser, request } = require('./helpers');
const crawlerService = require('../src/services/crawlerService');
const claudeService = require('../src/services/claudeService');

const CONTENT = '청년 고용률이 4년 만에 하락으로 돌아섰다. '.repeat(10);

const crawled = (overrides = {}) => ({
  title: '청년 고용률 4년 만에 하락 전환',
  publisher: '한겨레',
  thumbnailUrl: null,
  summary: '소개 문구',
  content: CONTENT,
  publishedAt: null,
  ...overrides,
});

const analysis = {
  commentary: '평론',
  framing: null,
  rhetoric: null,
  stakeholders: null,
  values: null,
  tags: [
    { name: '아노미', category: '사회학', description: '설명', reason: '근거', explanation: '풀이' },
    { name: '상대적 박탈감', category: '사회학', description: '설명2', reason: '근거2', explanation: '풀이2' },
  ],
};

// 크롤러와 Claude를 가짜로 바꾼다. 실제 네트워크·API 호출은 하지 않는다.
function stubAnalysis({ content } = {}) {
  return {
    crawl: mock.method(crawlerService, 'crawlArticle', async () => crawled(content && { content })),
    analyze: mock.method(claudeService, 'analyzeArticleTags', async () => analysis),
  };
}

const saveBody = (overrides = {}) => ({
  url: 'https://news.example.com/default',
  title: '기사',
  content: CONTENT,
  tags: [{ name: '아노미', reason: '근거' }],
  ...overrides,
});

describe('기사 스크랩: 분석과 저장 분리', () => {
  let server;
  let me;
  let call;

  before(async () => {
    server = await startServer();
    me = await createTestUser();
    call = request(server.baseUrl, me.token);
  });

  afterEach(() => mock.restoreAll());

  after(async () => {
    await me.remove();
    await server.close();
    await prisma.$disconnect();
  });

  test('POST /articles/analyze는 결과만 돌려주고 DB에 저장하지 않는다', async () => {
    stubAnalysis();
    const url = 'https://news.example.com/a1';

    const res = await call('POST', '/articles/analyze', { url });

    assert.equal(res.status, 200);
    assert.equal(res.body.url, url);
    assert.equal(res.body.publisher, '한겨레');
    assert.deepEqual(res.body.tags.map((t) => t.name), ['아노미', '상대적 박탈감']);
    assert.equal(await prisma.article.count({ where: { userId: me.user.id } }), 0);
    assert.equal(await prisma.tag.count({ where: { userId: me.user.id } }), 0);
  });

  test('analyze는 url 형식을 먼저 확인하고 잘못되면 크롤링하지 않는다', async () => {
    const { crawl } = stubAnalysis();

    const missing = await call('POST', '/articles/analyze', {});
    const notHttp = await call('POST', '/articles/analyze', { url: 'ftp://example.com/a' });

    assert.equal(missing.status, 400);
    assert.equal(notHttp.status, 400);
    assert.ok(missing.body.message);
    assert.equal(crawl.mock.callCount(), 0);
  });

  test('본문이 짧으면 Claude를 호출하지 않고 400 { message }를 돌려준다', async () => {
    const { analyze } = stubAnalysis({ content: '짧음' });

    const res = await call('POST', '/articles/analyze', { url: 'https://news.example.com/short' });

    assert.equal(res.status, 400);
    assert.ok(res.body.message);
    assert.equal(res.body.error, undefined);
    assert.equal(analyze.mock.callCount(), 0);
  });

  test('승인한 태그만 저장하고, 새 태그는 내 태그로 만든다', async () => {
    stubAnalysis();
    const { body: result } = await call('POST', '/articles/analyze', { url: 'https://news.example.com/a2' });

    // 사용자가 두 번째 태그를 거절했다
    const res = await call('POST', '/articles', { ...result, tags: [result.tags[0]] });

    assert.equal(res.status, 201);
    assert.equal(res.body.userId, me.user.id);
    assert.equal(res.body.publisher, '한겨레');
    assert.equal(res.body.commentary, '평론');
    assert.equal(res.body.articleTags.length, 1);
    assert.equal(res.body.articleTags[0].tag.name, '아노미');
    assert.equal(res.body.articleTags[0].tag.userId, me.user.id);
    assert.equal(res.body.articleTags[0].tag.description, '설명');
    assert.equal(res.body.articleTags[0].reason, '근거');
    assert.equal(res.body.articleTags[0].explanation, '풀이');
    assert.equal(await prisma.tag.count({ where: { userId: me.user.id } }), 1);
  });

  test('tagId로 내 기존 태그를 다시 쓴다', async () => {
    const existing = await prisma.tag.findFirstOrThrow({ where: { userId: me.user.id, name: '아노미' } });

    const res = await call(
      'POST',
      '/articles',
      saveBody({
        url: 'https://news.example.com/a3',
        tags: [{ tagId: existing.id, reason: '근거3', explanation: '풀이3' }],
      })
    );

    assert.equal(res.status, 201);
    assert.equal(res.body.articleTags[0].tagId, existing.id);
    assert.equal(await prisma.tag.count({ where: { userId: me.user.id } }), 1);
  });

  test('다른 사용자의 태그 ID로는 저장할 수 없고, 기사도 남지 않는다', async () => {
    const other = await createTestUser();
    try {
      const otherTag = await prisma.tag.create({ data: { userId: other.user.id, name: '판옵티콘' } });
      const url = 'https://news.example.com/a4';

      const res = await call('POST', '/articles', saveBody({ url, tags: [{ tagId: otherTag.id, reason: '근거' }] }));

      assert.equal(res.status, 400);
      assert.equal(await prisma.article.count({ where: { userId: me.user.id, url } }), 0);
    } finally {
      await other.remove();
    }
  });

  test('같은 태그가 두 번 들어 있으면 400이고 새 태그도 만들어지지 않는다', async () => {
    const tagCount = await prisma.tag.count({ where: { userId: me.user.id } });

    const res = await call(
      'POST',
      '/articles',
      saveBody({
        url: 'https://news.example.com/a5',
        tags: [
          { name: '낙인 효과', reason: '근거' },
          { name: '낙인 효과', reason: '근거' },
        ],
      })
    );

    assert.equal(res.status, 400);
    assert.equal(await prisma.tag.count({ where: { userId: me.user.id } }), tagCount);
  });

  test('저장 요청의 필수값·길이·태그 개수를 확인한다', async () => {
    const url = 'https://news.example.com/a6';
    const cases = [
      { url: 'not-a-url' },
      { title: '' },
      { content: '짧음' },
      { content: 'x'.repeat(5001) },
      { tags: [] },
      { tags: Array.from({ length: 11 }, (_, i) => ({ name: `t${i}`, reason: 'r' })) },
      { tags: [{ name: '아노미' }] },
      { tags: [{ name: 'x'.repeat(51), reason: 'r' }] },
      { publishedAt: '날짜 아님' },
    ];

    for (const overrides of cases) {
      const res = await call('POST', '/articles', saveBody({ url, ...overrides }));
      assert.equal(res.status, 400, JSON.stringify(overrides).slice(0, 80));
      assert.ok(res.body.message);
    }
    assert.equal(await prisma.article.count({ where: { userId: me.user.id, url } }), 0);
  });

  test('이미 저장한 URL은 analyze와 저장 모두 409', async () => {
    const { crawl } = stubAnalysis();
    const url = 'https://news.example.com/a2';

    const analyzed = await call('POST', '/articles/analyze', { url });
    const saved = await call('POST', '/articles', saveBody({ url }));

    assert.equal(analyzed.status, 409);
    assert.ok(analyzed.body.articleId);
    assert.equal(crawl.mock.callCount(), 0);
    assert.equal(saved.status, 409);
    assert.ok(saved.body.message);
  });

  test('토큰 없이 호출하면 401', async () => {
    const anonymous = request(server.baseUrl);
    assert.equal((await anonymous('POST', '/articles/analyze', { url: 'https://example.com' })).status, 401);
    assert.equal((await anonymous('POST', '/articles', {})).status, 401);
  });
});
