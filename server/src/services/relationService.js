const prisma = require('../prisma');
const httpError = require('../utils/httpError');

const TAG_BRIEF = { select: { id: true, name: true } };

// 관계 + 양 끝 개념 + 근거 스크랩 (관리 목록·상세용)
const RELATION_INCLUDE = {
  tagA: TAG_BRIEF,
  tagB: TAG_BRIEF,
  evidences: {
    include: {
      article: { select: { id: true, title: true, publisher: true, createdAt: true } },
      bookScrap: { select: { id: true, bookTitle: true, page: true, summary: true, createdAt: true } },
    },
  },
};

// 무방향 관계는 항상 작은 id를 tagA로 저장한다 (DB CHECK 제약 tagAId < tagBId)
const orderPair = (x, y) => (x < y ? [x, y] : [y, x]);

// 근거 스크랩 한 건을 화면용으로 바꾼다. 책은 제목 자리에 요약을 쓴다 (10-29 결정)
function toEvidence(e) {
  if (e.article) {
    return { kind: 'article', id: e.article.id, title: e.article.title, source: e.article.publisher, createdAt: e.article.createdAt };
  }
  const b = e.bookScrap;
  return { kind: 'book', id: b.id, title: b.summary, source: b.bookTitle, page: b.page, createdAt: b.createdAt };
}

function toRelation(r) {
  return {
    id: r.id,
    status: r.status,
    reason: r.reason,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    tagA: r.tagA,
    tagB: r.tagB,
    evidences: r.evidences.map(toEvidence),
  };
}

// 내 관계 목록 (관리 화면). status를 주면 그 상태만. 최근에 바뀐 것부터
async function listRelations(userId, { status } = {}) {
  const relations = await prisma.conceptRelation.findMany({
    where: { tagA: { userId }, ...(status && { status }) },
    include: RELATION_INCLUDE,
    orderBy: { updatedAt: 'desc' },
  });
  return relations.map(toRelation);
}

async function findOwnRelation(userId, id) {
  const relation = await prisma.conceptRelation.findFirst({
    where: { id, tagA: { userId } },
    include: RELATION_INCLUDE,
  });
  if (!relation) throw httpError(404, '관계를 찾을 수 없습니다.');
  return relation;
}

async function getRelation(userId, id) {
  return toRelation(await findOwnRelation(userId, id));
}

// 승인·거절·되돌리기(상태 변경)와 이유 수정. 연결 끊기도 REJECTED로 바꿔 보존한다 (재제안 방지)
async function updateRelation(userId, id, { status, reason }) {
  await findOwnRelation(userId, id);
  const updated = await prisma.conceptRelation.update({
    where: { id },
    data: { ...(status && { status }), ...(reason !== undefined && { reason }) },
    include: RELATION_INCLUDE,
  });
  return toRelation(updated);
}

// 근거가 하나도 남지 않은 관계를 지운다. 거절한 관계는 같은 쌍 재제안을 막기 위해 남긴다 (doc/plan.md 3장)
// 스크랩을 지우는 트랜잭션 안에서, 지우기 전에 모아 둔 관계 id로 호출한다.
async function removeOrphanRelations(tx, relationIds) {
  if (!relationIds.length) return 0;
  const { count } = await tx.conceptRelation.deleteMany({
    where: { id: { in: relationIds }, status: { not: 'REJECTED' }, evidences: { none: {} } },
  });
  if (count) console.log(`[관계] 근거가 사라진 관계 ${count}개 삭제`);
  return count;
}

// 스크랩을 지우기 전에, 그 스크랩을 근거로 가진 관계 id를 모은다
async function relationIdsByEvidence(tx, where) {
  const evidences = await tx.conceptRelationEvidence.findMany({ where, select: { relationId: true } });
  return [...new Set(evidences.map((e) => e.relationId))];
}

// ----- 그래프 (마인드맵·홈 미리보기) -----

const NODE_SELECT = {
  id: true,
  name: true,
  createdAt: true,
  _count: { select: { articleTags: true, bookTags: true } },
};

const toNode = (t) => ({ id: t.id, name: t.name, createdAt: t.createdAt, scrapCount: t._count.articleTags + t._count.bookTags });

const toLink = (r) => ({ id: r.id, tagAId: r.tagAId, tagBId: r.tagBId, status: r.status, reason: r.reason });

// 거절한 관계는 그래프에 그리지 않는다
const VISIBLE = { status: { not: 'REJECTED' } };

// 노드 집합 안의 연결만 고른다
async function linksAmong(userId, ids) {
  const relations = await prisma.conceptRelation.findMany({
    where: { ...VISIBLE, tagA: { userId }, tagAId: { in: ids }, tagBId: { in: ids } },
  });
  return relations.map(toLink);
}

// 전체 그래프: 내 개념 전부 + 거절하지 않은 관계 전부
async function fullGraph(userId) {
  const [tags, relations] = await Promise.all([
    prisma.tag.findMany({ where: { userId }, select: NODE_SELECT, orderBy: { createdAt: 'asc' } }),
    prisma.conceptRelation.findMany({ where: { ...VISIBLE, tagA: { userId } } }),
  ]);
  return { nodes: tags.map(toNode), links: relations.map(toLink) };
}

// 중심 노드 그래프 (마인드맵 기본 화면): 중심 개념 + 직접 연결된 개념, 그 사이의 연결
async function centerGraph(userId, centerId) {
  const center = await prisma.tag.findFirst({ where: { id: centerId, userId }, select: { id: true } });
  if (!center) throw httpError(404, '개념을 찾을 수 없습니다.');

  const touching = await prisma.conceptRelation.findMany({
    where: { ...VISIBLE, OR: [{ tagAId: centerId }, { tagBId: centerId }] },
    select: { tagAId: true, tagBId: true },
  });
  const ids = [centerId, ...touching.map((r) => (r.tagAId === centerId ? r.tagBId : r.tagAId))];

  const [tags, links] = await Promise.all([
    prisma.tag.findMany({ where: { userId, id: { in: ids } }, select: NODE_SELECT }),
    linksAmong(userId, ids),
  ]);
  return { centerId, nodes: tags.map(toNode), links };
}

// 홈 미리보기: 최근 추가한 개념 절반 + 연결이 많은 개념으로 limit개를 채운다 (doc/plan.md 8-1)
async function previewGraph(userId, limit) {
  const tags = await prisma.tag.findMany({
    where: { userId },
    select: { ...NODE_SELECT, relationsA: { where: VISIBLE, select: { id: true } }, relationsB: { where: VISIBLE, select: { id: true } } },
    orderBy: { createdAt: 'desc' },
  });
  const degree = (t) => t.relationsA.length + t.relationsB.length;

  const picked = new Map();
  for (const t of tags.slice(0, Math.ceil(limit / 2))) picked.set(t.id, t);
  for (const t of [...tags].sort((a, b) => degree(b) - degree(a))) {
    if (picked.size >= limit) break;
    picked.set(t.id, t);
  }

  const nodes = [...picked.values()];
  return { nodes: nodes.map(toNode), links: await linksAmong(userId, nodes.map((t) => t.id)) };
}

module.exports = {
  listRelations,
  getRelation,
  updateRelation,
  removeOrphanRelations,
  relationIdsByEvidence,
  fullGraph,
  centerGraph,
  previewGraph,
  orderPair,
  toEvidence,
  RELATION_INCLUDE,
};
