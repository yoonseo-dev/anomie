const prisma = require('../prisma');
const httpError = require('../utils/httpError');
const { orderPair } = require('./relationService');

async function findOwnTag(userId, id, db = prisma) {
  const tag = await db.tag.findFirst({ where: { id, userId } });
  if (!tag) throw httpError(404, '개념을 찾을 수 없습니다.');
  return tag;
}

// 내 개념 목록 (관리 화면 태그 탭). 스크랩 수·연결 수 포함
async function listConcepts(userId) {
  const tags = await prisma.tag.findMany({
    where: { userId },
    select: {
      id: true,
      name: true,
      category: true,
      createdAt: true,
      _count: { select: { articleTags: true, bookTags: true } },
      relationsA: { where: { status: { not: 'REJECTED' } }, select: { status: true } },
      relationsB: { where: { status: { not: 'REJECTED' } }, select: { status: true } },
    },
    orderBy: { createdAt: 'desc' },
  });
  return tags.map((t) => {
    const relations = [...t.relationsA, ...t.relationsB];
    return {
      id: t.id,
      name: t.name,
      category: t.category,
      createdAt: t.createdAt,
      scrapCount: t._count.articleTags + t._count.bookTags,
      linkCount: relations.filter((r) => r.status === 'APPROVED').length,
      suggestedCount: relations.filter((r) => r.status === 'SUGGESTED').length,
    };
  });
}

// 개념 상세 (doc/plan.md 8-3): 설명 → 내 스크랩에서의 등장(reason·excerpt) → 연결된 개념 → 처음 등장한 날짜
async function getConcept(userId, id) {
  await findOwnTag(userId, id);
  const tag = await prisma.tag.findUnique({
    where: { id },
    include: {
      articleTags: { include: { article: { select: { id: true, title: true, publisher: true, createdAt: true } } } },
      bookTags: {
        include: { bookScrap: { select: { id: true, bookTitle: true, author: true, page: true, summary: true, createdAt: true } } },
      },
      relationsA: { where: { status: { not: 'REJECTED' } }, include: { tagB: { select: { id: true, name: true } } } },
      relationsB: { where: { status: { not: 'REJECTED' } }, include: { tagA: { select: { id: true, name: true } } } },
    },
  });

  const scraps = [
    ...tag.articleTags.map((at) => ({
      kind: 'article',
      id: at.article.id,
      title: at.article.title,
      source: at.article.publisher,
      createdAt: at.article.createdAt,
      reason: at.reason,
      explanation: at.explanation,
    })),
    ...tag.bookTags.map((bt) => ({
      kind: 'book',
      id: bt.bookScrap.id,
      title: bt.bookScrap.summary, // 책은 제목 자리에 요약 (10-29 결정)
      source: bt.bookScrap.bookTitle,
      author: bt.bookScrap.author,
      page: bt.bookScrap.page,
      createdAt: bt.bookScrap.createdAt,
      reason: bt.reason,
      explanation: bt.explanation,
      excerpt: bt.excerpt,
    })),
  ].sort((a, b) => b.createdAt - a.createdAt);

  const links = [
    ...tag.relationsA.map((r) => ({ relationId: r.id, status: r.status, reason: r.reason, concept: r.tagB })),
    ...tag.relationsB.map((r) => ({ relationId: r.id, status: r.status, reason: r.reason, concept: r.tagA })),
  ].sort((a, b) => (a.status === b.status ? 0 : a.status === 'APPROVED' ? -1 : 1)); // 승인된 연결 먼저

  return {
    id: tag.id,
    name: tag.name,
    category: tag.category,
    description: tag.description,
    descriptionByAi: tag.descriptionByAi,
    createdAt: tag.createdAt,
    firstSeenAt: scraps.length ? scraps[scraps.length - 1].createdAt : null,
    scraps,
    links,
  };
}

// 사용자가 설명을 고치면 "AI 생성" 표시를 뗀다
async function updateDescription(userId, id, description) {
  await findOwnTag(userId, id);
  await prisma.tag.update({ where: { id }, data: { description, descriptionByAi: false } });
  return getConcept(userId, id);
}

// 개념 삭제. 스크랩 연결(ArticleTag·BookScrapTag)과 관계는 Cascade로 함께 지워진다. 스크랩 자체는 남는다
async function deleteConcept(userId, id) {
  await findOwnTag(userId, id);
  await prisma.tag.delete({ where: { id } });
}

// 상태가 다른 두 관계를 합칠 때 남길 상태: 승인 > 거절 > 제안
// (한쪽이라도 확정했으면 확정, 한쪽을 거절했으면 다시 제안하지 않는다)
const STATUS_RANK = { APPROVED: 3, REJECTED: 2, SUGGESTED: 1 };
const strongerStatus = (a, b) => (STATUS_RANK[a] >= STATUS_RANK[b] ? a : b);

// fromId 개념을 intoId에 합친다 (중복 태그 정리). 한 트랜잭션에서:
// 스크랩 연결을 옮기고(이미 into가 붙은 스크랩이면 from 쪽은 버림), 관계를 옮기고(겹치면 하나로, 근거는 모음),
// 둘 사이의 관계는 지운 뒤 from을 지운다. into의 이름·설명은 그대로 둔다.
async function mergeConcepts(userId, fromId, intoId) {
  if (fromId === intoId) throw httpError(400, '같은 개념끼리는 합칠 수 없습니다.');

  await prisma.$transaction(async (tx) => {
    await findOwnTag(userId, fromId, tx);
    await findOwnTag(userId, intoId, tx);

    for (const [model, scrapKey] of [
      ['articleTag', 'articleId'],
      ['bookScrapTag', 'bookScrapId'],
    ]) {
      const intoScraps = new Set((await tx[model].findMany({ where: { tagId: intoId }, select: { [scrapKey]: true } })).map((x) => x[scrapKey]));
      const fromLinks = await tx[model].findMany({ where: { tagId: fromId }, select: { id: true, [scrapKey]: true } });
      const duplicate = fromLinks.filter((x) => intoScraps.has(x[scrapKey])).map((x) => x.id);
      await tx[model].deleteMany({ where: { id: { in: duplicate } } });
      await tx[model].updateMany({ where: { tagId: fromId }, data: { tagId: intoId } });
    }

    const fromRelations = await tx.conceptRelation.findMany({
      where: { OR: [{ tagAId: fromId }, { tagBId: fromId }] },
      include: { evidences: true },
    });
    for (const r of fromRelations) {
      const other = r.tagAId === fromId ? r.tagBId : r.tagAId;
      if (other === intoId) continue; // 합치면 자기 자신과의 관계가 되므로 from과 함께 지운다
      const [tagAId, tagBId] = orderPair(intoId, other);
      const existing = await tx.conceptRelation.findUnique({ where: { tagAId_tagBId: { tagAId, tagBId } }, include: { evidences: true } });

      let targetId;
      if (existing) {
        targetId = existing.id;
        await tx.conceptRelation.update({ where: { id: existing.id }, data: { status: strongerStatus(existing.status, r.status) } });
      } else {
        targetId = (await tx.conceptRelation.create({ data: { tagAId, tagBId, reason: r.reason, status: r.status } })).id;
      }

      const has = new Set((existing?.evidences ?? []).map((e) => e.articleId ?? e.bookScrapId));
      const moved = r.evidences.filter((e) => !has.has(e.articleId ?? e.bookScrapId));
      if (moved.length) {
        await tx.conceptRelationEvidence.createMany({
          data: moved.map((e) => ({ relationId: targetId, articleId: e.articleId, bookScrapId: e.bookScrapId })),
        });
      }
    }

    await tx.tag.delete({ where: { id: fromId } }); // 남은 from 관계·근거는 Cascade로 지워진다
  });

  return getConcept(userId, intoId);
}

module.exports = { listConcepts, getConcept, updateDescription, deleteConcept, mergeConcepts };
