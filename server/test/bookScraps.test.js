const { test, describe, before, after, afterEach, mock } = require('node:test');
const assert = require('node:assert/strict');
const { prisma, startServer, createTestUser, request } = require('./helpers');
const { fakePng, fakeJpeg } = require('./images');
const ocrService = require('../src/services/ocrService');
const claudeService = require('../src/services/claudeService');

// 실제 책 페이지처럼 단어 중간에서 줄이 바뀐 OCR 텍스트
const OCR_TEXT = [
  '우리에게 솔로몬',
  '의 지혜가 있고 오디세우스의 책략과 꾀가 있다 해도, 우리의 자',
  '질을 사회적으로 인정받는 표지로 제시하지 못한다면 우리 존재',
  '는 그들에게 전혀 관심의 대상이 되지 못한다.',
].join('\n');

// claudeService.analyzeBookPage가 돌려주는 태그. excerpts는 문자열 하나 또는 구간 배열
const bookTag = (name, excerpts, overrides = {}) => ({
  existingTag: null,
  name,
  category: '사회학',
  description: '설명',
  reason: '근거',
  explanation: '풀이',
  excerpts: [excerpts].flat(),
  similarExisting: [],
  ...overrides,
});

const VERIFIED_EXCERPT = '우리의 자질을 사회적으로 인정받는 표지로 제시하지 못한다면 우리 존재는 그들에게 전혀 관심의 대상이 되지 못한다.';

const bookAnalysis = (tags) => ({ summary: '지위가 없으면 관심받지 못한다는 주장', tags });

// OCR과 Claude를 가짜로 바꾼다. 실제 Vision·Claude 호출은 하지 않는다.
function stubBook(tags = [bookTag('지위 불안', VERIFIED_EXCERPT)]) {
  return {
    ocr: mock.method(ocrService, 'extractText', async () => OCR_TEXT),
    analyze: mock.method(claudeService, 'analyzeBookPage', async () => bookAnalysis(tags)),
  };
}

// multipart로 사진과 책 정보를 보낸다
function uploader(baseUrl, token) {
  return async (fields, image = fakeJpeg(1200, 1600), filename = 'page.jpg') => {
    const form = new FormData();
    if (image) form.append('image', new Blob([image]), filename);
    for (const [key, value] of Object.entries(fields)) form.append(key, String(value));
    const res = await fetch(`${baseUrl}/book-scraps/analyze`, {
      method: 'POST',
      headers: token ? { Authorization: `Bearer ${token}` } : {},
      body: form,
    });
    return { status: res.status, body: await res.json() };
  };
}

const saveBody = (overrides = {}) => ({
  bookTitle: '불안',
  author: '알랭 드 보통',
  page: 30,
  summary: '요약',
  tags: [{ name: '지위 불안', reason: '근거', explanation: '풀이', excerpt: VERIFIED_EXCERPT }],
  ...overrides,
});

describe('책 스크랩: 사진 → OCR → 분석, 승인 후 저장', () => {
  let server;
  let me;
  let call;
  let upload;

  before(async () => {
    server = await startServer();
    me = await createTestUser();
    call = request(server.baseUrl, me.token);
    upload = uploader(server.baseUrl, me.token);
  });

  afterEach(() => mock.restoreAll());

  after(async () => {
    await me.remove();
    await server.close();
    await prisma.$disconnect();
  });

  test('analyze는 OCR 텍스트·요약·태그를 돌려주고 DB에는 저장하지 않는다', async () => {
    const { ocr, analyze } = stubBook();

    const res = await upload({ bookTitle: '불안', author: '알랭 드 보통', page: '30' });

    assert.equal(res.status, 200);
    assert.equal(res.body.bookTitle, '불안');
    assert.equal(res.body.page, 30);
    assert.equal(res.body.ocrText, OCR_TEXT);
    assert.equal(res.body.summary, '지위가 없으면 관심받지 못한다는 주장');
    assert.equal(res.body.tags[0].excerpt, VERIFIED_EXCERPT);
    assert.equal(ocr.mock.calls[0].arguments[0].length, fakeJpeg(1200, 1600).length);
    assert.equal(analyze.mock.calls[0].arguments[0].ocrText, OCR_TEXT);
    assert.equal(await prisma.bookScrap.count({ where: { userId: me.user.id } }), 0);
    assert.equal(await prisma.tag.count({ where: { userId: me.user.id } }), 0);
  });

  test('근거 문장은 공백·줄바꿈을 무시하고 대조하고, 글자가 다르면 "확인 필요"로 넘긴다', async () => {
    stubBook([
      bookTag('지위 불안', VERIFIED_EXCERPT),
      // OCR 줄바꿈 그대로 옮긴 경우도 통과
      bookTag('인정', '우리의 자\n질을   사회적으로 인정받는'),
      // 한 글자라도 바꾸면(맞춤법 교정 등) 실패
      bookTag('솔로몬의 지혜', '우리에게 솔로몬의 지혜가 있고 오디세우스의 책략과 꾀가 있다고 해도'),
      // 지어낸 문장
      bookTag('명성', '사람들은 명성을 갈망한다.'),
      // 떨어진 문장을 한 구간으로 이어 붙이면 실패 (10-29 실측에서 나온 경우)
      bookTag('조건부 사랑', '우리에게 솔로몬 … 전혀 관심의 대상이 되지 못한다.'),
      bookTag('지위', '우리에게 솔로몬 전혀 관심의 대상이 되지 못한다.'),
    ]);

    const res = await upload({ bookTitle: '불안' });

    assert.equal(res.status, 200);
    assert.deepEqual(
      res.body.tags.map((t) => [t.name, t.excerptVerified]),
      [
        ['지위 불안', true],
        ['인정', true],
        ['솔로몬의 지혜', false],
        ['명성', false],
        ['조건부 사랑', false],
        ['지위', false],
      ]
    );
  });

  test('떨어진 구간은 따로 대조하고 말줄임표로 이어 돌려준다', async () => {
    stubBook([
      bookTag('지위 불안', ['우리에게 솔로몬', '전혀 관심의 대상이 되지 못한다.']),
      bookTag('인정', ['우리에게 솔로몬', '사람들은 명성을 갈망한다.']), // 한 구간이라도 없으면 실패
      bookTag('명성', ['우리에게', '솔로몬', '의 지혜가', '있고']), // 구간은 3개까지
    ]);

    const res = await upload({ bookTitle: '불안' });

    const [joined, oneMissing, tooMany] = res.body.tags;
    assert.equal(joined.excerpt, '우리에게 솔로몬 … 전혀 관심의 대상이 되지 못한다.');
    assert.equal(joined.excerptVerified, true);
    assert.equal(oneMissing.excerptVerified, false);
    assert.equal(tooMany.excerptVerified, false);
    assert.equal('excerpts' in joined, false);
  });

  test('analyze는 기존 태그를 재사용한다 (기사와 같은 방식)', async () => {
    const tag = await prisma.tag.create({ data: { userId: me.user.id, name: '지위 불안', description: '내 설명' } });
    stubBook([bookTag('지위불안', VERIFIED_EXCERPT, { existingTag: tag, description: null })]);

    const res = await upload({ bookTitle: '불안' });

    assert.equal(res.body.tags[0].tagId, tag.id);
    assert.equal(res.body.tags[0].name, '지위 불안');
    assert.equal(res.body.tags[0].description, '내 설명');
    await prisma.tag.delete({ where: { id: tag.id } });
  });

  test('사진·책 정보가 잘못되면 OCR을 호출하지 않고 400', async () => {
    const { ocr } = stubBook();

    const cases = [
      [{ bookTitle: '불안' }, null], // 사진 없음
      [{ bookTitle: '불안' }, Buffer.from('GIF89a 아님'), 'page.gif'], // JPEG/PNG 아님
      [{ bookTitle: '불안' }, fakePng(200, 260), 'small.png'], // 해상도 부족 (10-29 표지 미리보기 크기)
      [{}, fakeJpeg(1200, 1600)], // 책 제목 없음
      [{ bookTitle: '불안', page: '삼십' }, fakeJpeg(1200, 1600)],
      [{ bookTitle: '불안', page: '0' }, fakeJpeg(1200, 1600)],
      [{ bookTitle: 'x'.repeat(201) }, fakeJpeg(1200, 1600)],
    ];
    for (const [fields, image, filename] of cases) {
      const res = await upload(fields, image, filename);
      assert.equal(res.status, 400, JSON.stringify(fields));
      assert.ok(res.body.message);
    }
    assert.equal(ocr.mock.callCount(), 0);
  });

  test('7MB가 넘는 사진은 400', async () => {
    const { ocr } = stubBook();
    const big = Buffer.concat([fakeJpeg(1200, 1600), Buffer.alloc(7 * 1024 * 1024)]);

    const res = await upload({ bookTitle: '불안' }, big);

    assert.equal(res.status, 400);
    assert.match(res.body.message, /7MB/);
    assert.equal(ocr.mock.callCount(), 0);
  });

  test('OCR이 글자를 못 찾으면 그 상태 코드와 안내를 그대로 돌려준다', async () => {
    const err = Object.assign(new Error('사진에서 글자를 찾지 못했습니다.'), { status: 422 });
    mock.method(ocrService, 'extractText', async () => {
      throw err;
    });

    const res = await upload({ bookTitle: '불안' });

    assert.equal(res.status, 422);
    assert.equal(res.body.message, '사진에서 글자를 찾지 못했습니다.');
  });

  test('승인한 태그와 근거 문장을 저장하고, 목록·상세에서 볼 수 있다', async () => {
    const res = await call('POST', '/book-scraps', saveBody());

    assert.equal(res.status, 201);
    assert.equal(res.body.bookTitle, '불안');
    assert.equal(res.body.page, 30);
    assert.equal(res.body.bookTags[0].excerpt, VERIFIED_EXCERPT);
    assert.equal(res.body.bookTags[0].tag.name, '지위 불안');
    assert.equal(res.body.bookTags[0].tag.userId, me.user.id);

    const list = await call('GET', '/book-scraps');
    assert.deepEqual(list.body.map((b) => b.id), [res.body.id]);
    const detail = await call('GET', `/book-scraps/${res.body.id}`);
    assert.equal(detail.body.bookTags[0].excerpt, VERIFIED_EXCERPT);
  });

  test('tagId로 기존 태그를 다시 쓰고, 사용자가 고친 근거 문장도 저장한다', async () => {
    const tag = await prisma.tag.findFirstOrThrow({ where: { userId: me.user.id, name: '지위 불안' } });
    const edited = '우리에게 솔로몬의 지혜가 있고 오디세우스의 책략과 꾀가 있다 해도'; // OCR 텍스트는 이미 버렸으므로 대조하지 않는다

    const res = await call(
      'POST',
      '/book-scraps',
      saveBody({ page: 31, tags: [{ tagId: tag.id, reason: '근거', excerpt: edited }] })
    );

    assert.equal(res.status, 201);
    assert.equal(res.body.bookTags[0].tagId, tag.id);
    assert.equal(res.body.bookTags[0].excerpt, edited);
    assert.equal(await prisma.tag.count({ where: { userId: me.user.id } }), 1);
  });

  test('저장 요청은 근거 문장·요약·책 제목이 없거나 너무 길면 400', async () => {
    const tag = { name: '소외', reason: '근거', excerpt: VERIFIED_EXCERPT };
    const cases = [
      { tags: [{ ...tag, excerpt: undefined }] },
      { tags: [{ ...tag, excerpt: 'x'.repeat(301) }] },
      { summary: '' },
      { bookTitle: '' },
      { page: 1.5 },
      { tags: [] },
    ];

    for (const overrides of cases) {
      const res = await call('POST', '/book-scraps', saveBody(overrides));
      assert.equal(res.status, 400, JSON.stringify(overrides).slice(0, 80));
    }
    assert.equal(await prisma.tag.count({ where: { userId: me.user.id, name: '소외' } }), 0);
  });

  test('다른 사용자의 책 스크랩은 볼 수도 지울 수도 없다', async () => {
    const other = await createTestUser();
    try {
      const theirs = await request(server.baseUrl, other.token)('POST', '/book-scraps', saveBody());

      assert.equal((await call('GET', `/book-scraps/${theirs.body.id}`)).status, 403);
      assert.equal((await call('DELETE', `/book-scraps/${theirs.body.id}`)).status, 403);
      assert.ok(!(await call('GET', '/book-scraps')).body.some((b) => b.id === theirs.body.id));
    } finally {
      await other.remove();
    }
  });

  test('삭제하면 연결(BookScrapTag)도 지워지고 태그는 남는다', async () => {
    const { body: saved } = await call('POST', '/book-scraps', saveBody({ page: 32 }));

    const res = await call('DELETE', `/book-scraps/${saved.id}`);

    assert.equal(res.status, 204);
    assert.equal((await call('GET', `/book-scraps/${saved.id}`)).status, 404);
    assert.equal(await prisma.bookScrapTag.count({ where: { bookScrapId: saved.id } }), 0);
    assert.equal(await prisma.tag.count({ where: { userId: me.user.id, name: '지위 불안' } }), 1);
  });

  test('토큰 없이 호출하면 401', async () => {
    const anonymous = uploader(server.baseUrl);
    assert.equal((await anonymous({ bookTitle: '불안' })).status, 401);
    assert.equal((await request(server.baseUrl)('POST', '/book-scraps', saveBody())).status, 401);
  });
});
