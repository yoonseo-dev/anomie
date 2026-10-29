const { test, describe, before, beforeEach, afterEach, after, mock } = require('node:test');
const assert = require('node:assert/strict');
const { prisma, createTestUser } = require('./helpers');
const claudeService = require('../src/services/claudeService');
const { suggestRelations, suggestInBackground, SCRAPS_PER_TAG } = require('../src/services/relationSuggestService');
const { orderPair } = require('../src/services/relationService');

const CONTENT = '본문 '.repeat(40);
const usage = { model: 'claude-haiku-4-5-20251001', inputTokens: 100, outputTokens: 50 };

// 1단계 가짜: 이름 쌍 목록을 받은 번호로 바꿔 돌려준다
function stubStage1(namePairs) {
  return mock.method(claudeService, 'suggestRelationCandidates', async ({ tags }) => {
    const ref = (name) => tags.find((t) => t.name === name)?.ref ?? 'T999';
    return { candidates: namePairs.map(([a, b]) => ({ a: ref(a), b: ref(b) })), usage };
  });
}

// 2단계 가짜: decide(candidates, scraps)가 돌려준 관계를 그대로 돌려준다
function stubStage2(decide) {
  return mock.method(claudeService, 'confirmRelations', async ({ candidates, scraps }) => ({
    relations: decide(candidates, scraps),
    usage,
  }));
}

// 후보 중 이름이 맞는 쌍을, text에 needle이 들어간 스크랩을 근거로 제안
const propose = (candidates, scraps, [x, y], needles, reason = '두 스크랩에서 이어진다') => {
  const c = candidates.find((k) => [k.aName, k.bName].sort().join() === [x, y].sort().join());
  return { a: c.a, b: c.b, reason, evidence: needles.map((n) => scraps.find((s) => s.text.includes(n))?.ref ?? 'S999') };
};

describe('관계 제안 (2단계, 스크랩 근거 필수)', () => {
  let me;
  let tags;
  let book;

  const createArticle = (title, tagNames, summary = `${title} 요약`) =>
    prisma.article.create({
      data: {
        userId: me.user.id,
        url: `https://news.example.com/${Math.random()}`,
        title,
        content: CONTENT,
        summary,
        articleTags: { create: tagNames.map((n) => ({ tagId: tags[n].id, reason: `${title}에서 ${n}`, explanation: '' })) },
      },
    });

  before(() => {
    process.env.ANALYSIS_LOG = 'off';
  });

  beforeEach(async () => {
    me = await createTestUser();
    tags = {};
    for (const name of ['판옵티콘', '감시사회', '소외', '아노미']) {
      tags[name] = await prisma.tag.create({ data: { userId: me.user.id, name } });
    }
    book = await prisma.bookScrap.create({
      data: {
        userId: me.user.id,
        bookTitle: '감시와 처벌',
        page: 309,
        summary: '판옵티콘은 보이지 않는 시선으로 스스로를 규율하게 한다',
        bookTags: { create: [{ tagId: tags['판옵티콘'].id, reason: '판옵티콘 정의', explanation: '', excerpt: '보이지 않는 시선' }] },
      },
    });
  });

  afterEach(async () => {
    mock.restoreAll();
    await me.remove();
  });

  after(async () => {
    await prisma.$disconnect();
  });

  test('책(이론)과 새 기사(현실)에 걸친 근거로 SUGGESTED 관계를 만든다', async () => {
    const article = await createArticle('배달 앱이 라이더 위치를 실시간 감시', ['감시사회', '소외']);
    const stage1 = stubStage1([['감시사회', '판옵티콘']]);
    const stage2 = stubStage2((c, s) => [propose(c, s, ['감시사회', '판옵티콘'], ['감시와 처벌', '배달 앱'], '판옵티콘처럼 앱이 감시한다')]);

    const created = await suggestRelations(me.user.id, { kind: 'article', id: article.id });

    assert.equal(created, 1);
    const [tagAId, tagBId] = orderPair(tags['감시사회'].id, tags['판옵티콘'].id);
    const relation = await prisma.conceptRelation.findUnique({
      where: { tagAId_tagBId: { tagAId, tagBId } },
      include: { evidences: true },
    });
    assert.equal(relation.status, 'SUGGESTED');
    assert.equal(relation.reason, '판옵티콘처럼 앱이 감시한다');
    assert.deepEqual(relation.evidences.map((e) => (e.articleId ? 'article' : 'book')).sort(), ['article', 'book']);

    // 1단계: 새 스크랩의 개념에 ★ 표시
    const sent = stage1.mock.calls[0].arguments[0].tags;
    assert.deepEqual(sent.filter((t) => t.isNew).map((t) => t.name).sort(), ['감시사회', '소외']);
    // 2단계: 원문이 아니라 요약·태그 이유·근거 문장을 넘긴다
    const scraps = stage2.mock.calls[0].arguments[0].scraps;
    const bookText = scraps.find((x) => x.text.includes('감시와 처벌')).text;
    assert.match(bookText, /요약: 판옵티콘은/);
    assert.match(bookText, /근거 문장: "보이지 않는 시선"/);
    assert.ok(scraps.every((x) => !x.text.includes(CONTENT.trim())));
  });

  test('한 기사 안의 두 개념(같은 스크랩 근거)도 관계가 된다', async () => {
    const article = await createArticle('플랫폼 노동', ['감시사회', '소외']);
    stubStage1([['감시사회', '소외']]);
    stubStage2((c, s) => [propose(c, s, ['감시사회', '소외'], ['플랫폼 노동'])]);

    assert.equal(await suggestRelations(me.user.id, { kind: 'article', id: article.id }), 1);
  });

  test('1단계에서 잘못된 후보(목록 밖 번호, 자기 자신, 새 개념 없는 쌍, 이미 있는 쌍)는 버리고, 남은 게 없으면 2단계를 부르지 않는다', async () => {
    const article = await createArticle('기사', ['감시사회']);
    // 감시사회—소외는 거절된 관계로 이미 있다
    const [a, b] = orderPair(tags['감시사회'].id, tags['소외'].id);
    await prisma.conceptRelation.create({ data: { tagAId: a, tagBId: b, reason: 'r', status: 'REJECTED' } });

    stubStage1([
      ['감시사회', '없는 개념'],
      ['감시사회', '감시사회'],
      ['판옵티콘', '아노미'], // 새 개념이 없음
      ['소외', '감시사회'], // 이미 있는 쌍 (순서 반대)
    ]);
    const stage2 = stubStage2(() => []);

    const created = await suggestRelations(me.user.id, { kind: 'article', id: article.id });

    assert.equal(created, 0);
    assert.equal(stage2.mock.callCount(), 0);
  });

  test('1단계에 이미 있는 쌍을 "제외할 쌍"으로 알려 준다', async () => {
    const article = await createArticle('기사', ['감시사회']);
    const [a, b] = orderPair(tags['판옵티콘'].id, tags['아노미'].id);
    await prisma.conceptRelation.create({ data: { tagAId: a, tagBId: b, reason: 'r', status: 'APPROVED' } });
    const stage1 = stubStage1([]);

    await suggestRelations(me.user.id, { kind: 'article', id: article.id });

    const { tags: sent, excludedPairs } = stage1.mock.calls[0].arguments[0];
    const ref = (n) => sent.find((t) => t.name === n).ref;
    assert.equal(excludedPairs.length, 1);
    assert.deepEqual(excludedPairs[0].split('|').sort(), [ref('판옵티콘'), ref('아노미')].sort());
  });

  test('2단계 검증: 후보에 없던 쌍, 두 개념이 다 붙지 않은 근거, 없는 근거 번호는 버린다', async () => {
    const article = await createArticle('배달 앱 감시', ['감시사회']);
    stubStage1([
      ['감시사회', '판옵티콘'],
      ['감시사회', '소외'],
    ]);
    stubStage2((c, s) => [
      // 소외가 붙은 스크랩이 근거에 없음
      propose(c, s, ['감시사회', '소외'], ['배달 앱']),
      // 없는 근거 번호
      { ...propose(c, s, ['감시사회', '판옵티콘'], ['감시와 처벌']), evidence: ['S999'] },
      // 후보에 없던 쌍
      { a: c[0].a, b: 'T999', reason: 'r', evidence: [] },
    ]);

    assert.equal(await suggestRelations(me.user.id, { kind: 'article', id: article.id }), 0);
    assert.equal(await prisma.conceptRelation.count({ where: { tagA: { userId: me.user.id } } }), 0);
  });

  test('2단계에는 상대 개념이 붙은 최근 스크랩을 개념마다 몇 개까지만 넘긴다', async () => {
    for (let i = 1; i <= SCRAPS_PER_TAG + 2; i++) await createArticle(`소외 기사 ${i}`, ['소외']);
    const article = await createArticle('새 기사', ['감시사회']);
    stubStage1([['감시사회', '소외']]);
    const stage2 = stubStage2(() => []);

    await suggestRelations(me.user.id, { kind: 'article', id: article.id });

    const scraps = stage2.mock.calls[0].arguments[0].scraps;
    assert.equal(scraps.filter((s) => s.text.includes('소외 기사')).length, SCRAPS_PER_TAG);
    assert.ok(scraps.some((s) => s.text.includes(`소외 기사 ${SCRAPS_PER_TAG + 2}`))); // 최근 것
    assert.ok(scraps[0].text.includes('새 기사')); // 새 스크랩이 맨 앞
  });

  test('다른 사용자의 스크랩은 근거로 넘기지 않는다', async () => {
    const other = await createTestUser();
    try {
      const theirTag = await prisma.tag.create({ data: { userId: other.user.id, name: '소외' } });
      await prisma.article.create({
        data: {
          userId: other.user.id,
          url: 'https://news.example.com/theirs',
          title: '남의 기사',
          content: CONTENT,
          summary: '남의 요약',
          articleTags: { create: [{ tagId: theirTag.id, reason: 'r', explanation: '' }] },
        },
      });
      const article = await createArticle('내 기사', ['감시사회']);
      stubStage1([['감시사회', '소외']]);
      const stage2 = stubStage2(() => []);

      await suggestRelations(me.user.id, { kind: 'article', id: article.id });

      const texts = stage2.mock.calls[0].arguments[0].scraps.map((s) => s.text).join();
      assert.ok(!texts.includes('남의 기사'));
    } finally {
      await other.remove();
    }
  });

  test('책 스크랩을 저장했을 때도 같은 방식으로 제안한다', async () => {
    await createArticle('배달 앱 감시', ['감시사회']);
    stubStage1([['판옵티콘', '감시사회']]);
    stubStage2((c, s) => [propose(c, s, ['감시사회', '판옵티콘'], ['감시와 처벌', '배달 앱'])]);

    assert.equal(await suggestRelations(me.user.id, { kind: 'book', id: book.id }), 1);
  });

  test('개념이 하나뿐이면 Claude를 부르지 않는다', async () => {
    const solo = await createTestUser();
    try {
      const tag = await prisma.tag.create({ data: { userId: solo.user.id, name: '아노미' } });
      const article = await prisma.article.create({
        data: {
          userId: solo.user.id,
          url: 'https://news.example.com/solo',
          title: '기사',
          content: CONTENT,
          summary: '요약',
          articleTags: { create: [{ tagId: tag.id, reason: 'r', explanation: '' }] },
        },
      });
      const stage1 = stubStage1([]);

      assert.equal(await suggestRelations(solo.user.id, { kind: 'article', id: article.id }), 0);
      assert.equal(stage1.mock.callCount(), 0);
    } finally {
      await solo.remove();
    }
  });

  test('RELATION_SUGGEST=off면 백그라운드 제안을 시작하지 않는다', async () => {
    const stage1 = stubStage1([]);
    suggestInBackground(me.user.id, { kind: 'book', id: book.id });
    await new Promise((r) => setTimeout(r, 50));
    assert.equal(stage1.mock.callCount(), 0);
  });
});
