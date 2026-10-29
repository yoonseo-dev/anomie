const { test, describe, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { prisma, startServer, createTestUser, request } = require('./helpers');
const { orderPair } = require('../src/services/relationService');

const CONTENT = '본문 '.repeat(40);

// 테스트용 데이터. 매 테스트마다 사용자를 새로 만들어 서로 영향이 없게 한다
async function seed(userId) {
  const tag = (name) => prisma.tag.create({ data: { userId, name, description: `${name} 설명` } });
  const [anomie, alienation, panopticon, surveillance, isolated] = await Promise.all(
    ['아노미', '소외', '판옵티콘', '감시사회', '고립된 개념'].map(tag)
  );

  const article = await prisma.article.create({
    data: {
      userId,
      url: `https://news.example.com/${Math.random()}`,
      title: '배달 라이더 감시',
      publisher: '경향신문',
      content: CONTENT,
      summary: '앱이 라이더를 감시한다',
      articleTags: {
        create: [
          { tagId: surveillance.id, reason: '감시 근거', explanation: '풀이' },
          { tagId: alienation.id, reason: '소외 근거', explanation: '풀이' },
        ],
      },
    },
  });
  const book = await prisma.bookScrap.create({
    data: {
      userId,
      bookTitle: '감시와 처벌',
      author: '미셸 푸코',
      page: 309,
      summary: '판옵티콘은 보이지 않는 감시로 규율한다',
      bookTags: { create: [{ tagId: panopticon.id, reason: '판옵티콘 근거', explanation: '풀이', excerpt: '근거 문장' }] },
    },
  });

  const relation = async (x, y, status, evidences) => {
    const [tagAId, tagBId] = orderPair(x.id, y.id);
    return prisma.conceptRelation.create({
      data: { tagAId, tagBId, status, reason: `${x.name}—${y.name}`, evidences: { create: evidences } },
    });
  };
  const rels = {
    // 같은 기사 안의 근거
    survAlien: await relation(surveillance, alienation, 'APPROVED', [{ articleId: article.id }]),
    // 책과 기사에 걸친 근거
    panSurv: await relation(panopticon, surveillance, 'SUGGESTED', [{ articleId: article.id }, { bookScrapId: book.id }]),
    // 거절한 관계 (근거는 기사 하나)
    anomieAlien: await relation(anomie, alienation, 'REJECTED', [{ articleId: article.id }]),
  };

  return { tags: { anomie, alienation, panopticon, surveillance, isolated }, article, book, rels };
}

describe('관계·그래프·개념 관리 API', () => {
  let server;
  let me;
  let call;
  let d;

  before(async () => {
    server = await startServer();
  });

  beforeEach(async () => {
    if (me) await me.remove();
    me = await createTestUser();
    call = request(server.baseUrl, me.token);
    d = await seed(me.user.id);
  });

  after(async () => {
    if (me) await me.remove();
    await server.close();
    await prisma.$disconnect();
  });

  describe('그래프', () => {
    test('전체 그래프는 모든 개념과 거절하지 않은 관계를 돌려준다', async () => {
      const res = await call('GET', '/concepts/graph');

      assert.equal(res.status, 200);
      assert.equal(res.body.nodes.length, 5);
      assert.deepEqual(res.body.links.map((l) => l.id).sort(), [d.rels.survAlien.id, d.rels.panSurv.id].sort());
      const surv = res.body.nodes.find((n) => n.id === d.tags.surveillance.id);
      assert.equal(surv.scrapCount, 1);
      const pan = res.body.links.find((l) => l.id === d.rels.panSurv.id);
      assert.equal(pan.status, 'SUGGESTED');
      assert.ok(pan.tagAId < pan.tagBId);
    });

    test('중심 노드 그래프는 중심과 직접 연결된 개념, 그 사이의 연결만 담는다', async () => {
      const res = await call('GET', `/concepts/graph?center=${d.tags.surveillance.id}`);

      assert.equal(res.status, 200);
      assert.deepEqual(
        res.body.nodes.map((n) => n.name).sort(),
        ['감시사회', '소외', '판옵티콘'].sort()
      );
      assert.equal(res.body.links.length, 2);

      // 거절한 관계로만 이어진 개념은 나오지 않는다
      const anomie = await call('GET', `/concepts/graph?center=${d.tags.anomie.id}`);
      assert.deepEqual(anomie.body.nodes.map((n) => n.name), ['아노미']);
      assert.deepEqual(anomie.body.links, []);
    });

    test('미리보기는 limit개까지, 연결 많은 개념을 포함한다', async () => {
      const res = await call('GET', '/concepts/graph/preview?limit=3');

      assert.equal(res.body.nodes.length, 3);
      assert.ok(res.body.nodes.some((n) => n.id === d.tags.surveillance.id)); // 연결 2개로 가장 많음
      const ids = new Set(res.body.nodes.map((n) => n.id));
      assert.ok(res.body.links.every((l) => ids.has(l.tagAId) && ids.has(l.tagBId)));
    });

    test('다른 사용자의 개념을 중심으로 조회하면 404', async () => {
      const other = await createTestUser();
      try {
        const res = await request(server.baseUrl, other.token)('GET', `/concepts/graph?center=${d.tags.surveillance.id}`);
        assert.equal(res.status, 404);
      } finally {
        await other.remove();
      }
    });
  });

  describe('관계 관리', () => {
    test('상태별 목록에 양 끝 개념과 근거 스크랩(기사·책)이 함께 온다', async () => {
      const res = await call('GET', '/relations?status=SUGGESTED');

      assert.equal(res.status, 200);
      assert.equal(res.body.length, 1);
      const [r] = res.body;
      assert.deepEqual([r.tagA.name, r.tagB.name].sort(), ['감시사회', '판옵티콘'].sort());
      assert.deepEqual(r.evidences.map((e) => e.kind).sort(), ['article', 'book']);
      const book = r.evidences.find((e) => e.kind === 'book');
      assert.equal(book.title, '판옵티콘은 보이지 않는 감시로 규율한다'); // 책은 제목 자리에 요약
      assert.equal(book.source, '감시와 처벌');

      assert.equal((await call('GET', '/relations')).body.length, 3);
      assert.equal((await call('GET', '/relations?status=WRONG')).status, 400);
    });

    test('승인 → 연결 끊기(거절로 보존) → 되돌리기, 이유 수정', async () => {
      const id = d.rels.panSurv.id;

      assert.equal((await call('PATCH', `/relations/${id}`, { status: 'APPROVED' })).body.status, 'APPROVED');
      assert.equal((await call('PATCH', `/relations/${id}`, { status: 'REJECTED' })).body.status, 'REJECTED');
      assert.ok(await prisma.conceptRelation.findUnique({ where: { id } })); // 지우지 않는다
      assert.equal((await call('PATCH', `/relations/${id}`, { status: 'APPROVED' })).body.status, 'APPROVED');

      const edited = await call('PATCH', `/relations/${id}`, { reason: '감시의 내면화' });
      assert.equal(edited.body.reason, '감시의 내면화');
      assert.equal(edited.body.status, 'APPROVED');
    });

    test('잘못된 요청은 400, 다른 사용자의 관계는 404', async () => {
      const id = d.rels.panSurv.id;
      assert.equal((await call('PATCH', `/relations/${id}`, {})).status, 400);
      assert.equal((await call('PATCH', `/relations/${id}`, { status: 'DELETED' })).status, 400);
      assert.equal((await call('PATCH', `/relations/${id}`, { reason: '' })).status, 400);

      const other = await createTestUser();
      try {
        const theirs = request(server.baseUrl, other.token);
        assert.equal((await theirs('GET', `/relations/${id}`)).status, 404);
        assert.equal((await theirs('PATCH', `/relations/${id}`, { status: 'APPROVED' })).status, 404);
        assert.deepEqual((await theirs('GET', '/relations')).body, []);
      } finally {
        await other.remove();
      }
    });
  });

  describe('스크랩 삭제 시 관계 정리', () => {
    test('근거가 모두 사라진 관계는 지우고, 근거가 남은 관계와 거절한 관계는 남긴다', async () => {
      const res = await call('DELETE', `/articles/${d.article.id}`);

      assert.equal(res.status, 204);
      const left = await prisma.conceptRelation.findMany({ where: { tagA: { userId: me.user.id } }, include: { evidences: true } });
      const byId = new Map(left.map((r) => [r.id, r]));
      assert.equal(byId.has(d.rels.survAlien.id), false); // 기사가 유일한 근거 → 삭제
      assert.equal(byId.get(d.rels.panSurv.id).evidences.length, 1); // 책 근거가 남음
      assert.equal(byId.get(d.rels.anomieAlien.id).status, 'REJECTED'); // 근거가 없어도 보존
      assert.equal(byId.get(d.rels.anomieAlien.id).evidences.length, 0);
    });

    test('책 스크랩을 지워도 같은 규칙을 따른다', async () => {
      await call('DELETE', `/book-scraps/${d.book.id}`);
      await call('DELETE', `/articles/${d.article.id}`);

      const left = await prisma.conceptRelation.findMany({ where: { tagA: { userId: me.user.id } } });
      assert.deepEqual(left.map((r) => r.id), [d.rels.anomieAlien.id]);
    });
  });

  describe('개념', () => {
    test('목록에 스크랩 수·승인 연결 수·제안 수가 들어 있다', async () => {
      const res = await call('GET', '/concepts');

      const surv = res.body.find((c) => c.id === d.tags.surveillance.id);
      assert.deepEqual([surv.scrapCount, surv.linkCount, surv.suggestedCount], [1, 1, 1]);
      const anomie = res.body.find((c) => c.id === d.tags.anomie.id);
      assert.deepEqual([anomie.linkCount, anomie.suggestedCount], [0, 0]); // 거절은 세지 않는다
    });

    test('상세는 설명, 스크랩에서의 등장(책은 근거 문장), 연결(승인 먼저)을 담는다', async () => {
      const res = await call('GET', `/concepts/${d.tags.surveillance.id}`);

      assert.equal(res.status, 200);
      assert.equal(res.body.description, '감시사회 설명');
      assert.equal(res.body.descriptionByAi, true);
      assert.deepEqual(res.body.scraps.map((s) => [s.kind, s.reason]), [['article', '감시 근거']]);
      assert.deepEqual(res.body.links.map((l) => [l.concept.name, l.status]), [
        ['소외', 'APPROVED'],
        ['판옵티콘', 'SUGGESTED'],
      ]);
      assert.ok(res.body.firstSeenAt);

      const pan = await call('GET', `/concepts/${d.tags.panopticon.id}`);
      assert.equal(pan.body.scraps[0].excerpt, '근거 문장');
      assert.equal(pan.body.scraps[0].page, 309);
    });

    test('설명을 고치면 AI 생성 표시가 빠진다', async () => {
      const res = await call('PATCH', `/concepts/${d.tags.anomie.id}`, { description: '내가 쓴 설명' });

      assert.equal(res.body.description, '내가 쓴 설명');
      assert.equal(res.body.descriptionByAi, false);
      assert.equal((await call('PATCH', `/concepts/${d.tags.anomie.id}`, { description: '' })).status, 400);
    });

    test('개념을 지우면 관계와 스크랩 연결도 지워지고 스크랩은 남는다', async () => {
      const res = await call('DELETE', `/concepts/${d.tags.surveillance.id}`);

      assert.equal(res.status, 204);
      assert.equal(await prisma.conceptRelation.count({ where: { id: { in: [d.rels.survAlien.id, d.rels.panSurv.id] } } }), 0);
      assert.ok(await prisma.article.findUnique({ where: { id: d.article.id } }));
      assert.equal((await call('GET', `/concepts/${d.tags.surveillance.id}`)).status, 404);
    });

    test('병합: 스크랩 연결·관계를 옮기고, 겹치면 하나로(강한 상태·근거 합침), 둘 사이 관계는 지운다', async () => {
      // 감시사회 → 판옵티콘으로 합친다.
      // - 기사의 '감시사회' 태그가 판옵티콘으로 옮겨진다
      // - 감시사회—소외(승인) → 판옵티콘—소외로 이동
      // - 감시사회—판옵티콘(제안)은 자기 자신과의 관계가 되므로 삭제
      // 겹치는 경우를 만들기 위해 판옵티콘—소외(제안, 책 근거)를 미리 둔다
      const [a, b] = orderPair(d.tags.panopticon.id, d.tags.alienation.id);
      await prisma.conceptRelation.create({
        data: { tagAId: a, tagBId: b, status: 'SUGGESTED', reason: '기존', evidences: { create: [{ bookScrapId: d.book.id }] } },
      });

      const res = await call('POST', `/concepts/${d.tags.surveillance.id}/merge`, { intoId: d.tags.panopticon.id });

      assert.equal(res.status, 200);
      assert.equal(res.body.id, d.tags.panopticon.id);
      assert.equal(await prisma.tag.count({ where: { id: d.tags.surveillance.id } }), 0);
      assert.deepEqual(res.body.scraps.map((s) => s.kind).sort(), ['article', 'book']);

      const merged = await prisma.conceptRelation.findUnique({
        where: { tagAId_tagBId: { tagAId: a, tagBId: b } },
        include: { evidences: true },
      });
      assert.equal(merged.status, 'APPROVED'); // 승인 > 제안
      assert.deepEqual(merged.evidences.map((e) => (e.articleId ? 'article' : 'book')).sort(), ['article', 'book']);
      assert.equal(await prisma.conceptRelation.count({ where: { id: d.rels.panSurv.id } }), 0);
    });

    test('병합: 같은 스크랩에 두 개념이 다 붙어 있으면 하나만 남긴다', async () => {
      // 기사에는 감시사회·소외가 모두 붙어 있다
      const res = await call('POST', `/concepts/${d.tags.surveillance.id}/merge`, { intoId: d.tags.alienation.id });

      assert.equal(res.status, 200);
      assert.equal(await prisma.articleTag.count({ where: { articleId: d.article.id } }), 1);
      assert.equal(res.body.scraps.length, 1);
    });

    test('병합은 같은 개념끼리나 다른 사용자의 개념과는 할 수 없다', async () => {
      const self = await call('POST', `/concepts/${d.tags.anomie.id}/merge`, { intoId: d.tags.anomie.id });
      assert.equal(self.status, 400);

      const other = await createTestUser();
      try {
        const theirTag = await prisma.tag.create({ data: { userId: other.user.id, name: '아노미' } });
        const res = await call('POST', `/concepts/${d.tags.anomie.id}/merge`, { intoId: theirTag.id });
        assert.equal(res.status, 404);
        assert.ok(await prisma.tag.findUnique({ where: { id: d.tags.anomie.id } }));
      } finally {
        await other.remove();
      }
    });
  });

  test('토큰 없이 호출하면 401', async () => {
    const anonymous = request(server.baseUrl);
    assert.equal((await anonymous('GET', '/concepts')).status, 401);
    assert.equal((await anonymous('GET', '/relations')).status, 401);
  });
});
