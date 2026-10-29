const prisma = require('../prisma');
const claudeService = require('./claudeService');
const evalService = require('./evalService');
const { orderPair } = require('./relationService');

// 호출 1회당 상한 (doc/plan.md 11장 "관계 제안 개수 상한" — 10-29 정함, 실측 후 조정)
const MAX_CANDIDATES = 8; // 1단계 후보 쌍
const SCRAPS_PER_TAG = 3; // 2단계에서 상대 개념마다 넘길 최근 스크랩 수
const MAX_SUGGESTIONS = 3; // 2단계 최종 제안

const pairKey = (x, y) => orderPair(x, y).join('|');

// 스크랩 하나를 { key, tagIds, text } 로 정리한다. text는 Claude에 넘길 내용 (원문 대신 요약·태그 이유·근거 문장)
function articleToScrap(a, tagNames) {
  const tags = a.articleTags.filter((t) => tagNames.has(t.tagId));
  return {
    key: `article:${a.id}`,
    articleId: a.id,
    tagIds: new Set(a.articleTags.map((t) => t.tagId)),
    text: [
      `뉴스 「${a.title}」${a.publisher ? ` (${a.publisher})` : ''}`,
      `요약: ${a.summary}`,
      ...tags.map((t) => `- ${tagNames.get(t.tagId)}: ${t.reason}`),
    ].join('\n'),
  };
}

function bookToScrap(b, tagNames) {
  const tags = b.bookTags.filter((t) => tagNames.has(t.tagId));
  return {
    key: `book:${b.id}`,
    bookScrapId: b.id,
    tagIds: new Set(b.bookTags.map((t) => t.tagId)),
    text: [
      `책 『${b.bookTitle}』${b.author ? ` (${b.author})` : ''}${b.page ? ` ${b.page}쪽` : ''}`,
      `요약: ${b.summary}`,
      ...tags.map((t) => `- ${tagNames.get(t.tagId)}: ${t.reason} / 근거 문장: "${t.excerpt}"`),
    ].join('\n'),
  };
}

const ARTICLE_SELECT = {
  id: true,
  title: true,
  publisher: true,
  summary: true,
  articleTags: { select: { tagId: true, reason: true } },
};
const BOOK_SELECT = {
  id: true,
  bookTitle: true,
  author: true,
  page: true,
  summary: true,
  bookTags: { select: { tagId: true, reason: true, excerpt: true } },
};

// 방금 저장한 스크랩을 기준으로 관계를 제안해 SUGGESTED로 저장한다. 만든 관계 수를 돌려준다.
// scrap: { kind: 'article' | 'book', id }
async function suggestRelations(userId, scrap) {
  const isArticle = scrap.kind === 'article';
  const saved = isArticle
    ? await prisma.article.findFirst({ where: { id: scrap.id, userId }, select: ARTICLE_SELECT })
    : await prisma.bookScrap.findFirst({ where: { id: scrap.id, userId }, select: BOOK_SELECT });
  if (!saved) return 0;

  const newTagIds = new Set((isArticle ? saved.articleTags : saved.bookTags).map((t) => t.tagId));
  const allTags = await prisma.tag.findMany({ where: { userId }, select: { id: true, name: true }, orderBy: { createdAt: 'asc' } });
  // 새 개념 하나뿐이고 다른 개념도 없으면 이을 대상이 없다
  if (allTags.length < 2) return 0;

  const existing = await prisma.conceptRelation.findMany({
    where: { tagA: { userId } },
    select: { tagAId: true, tagBId: true },
  });
  const existingKeys = new Set(existing.map((r) => `${r.tagAId}|${r.tagBId}`));

  // ----- 1단계: 이름만 보고 후보 쌍 -----
  const refOf = new Map();
  const byRef = new Map();
  allTags.forEach((t, i) => {
    refOf.set(t.id, `T${i + 1}`);
    byRef.set(`T${i + 1}`, t);
  });
  const excludedPairs = existing
    .filter((r) => refOf.has(r.tagAId) && refOf.has(r.tagBId))
    .map((r) => `${refOf.get(r.tagAId)}|${refOf.get(r.tagBId)}`);

  const stage1 = await claudeService.suggestRelationCandidates({
    tags: allTags.map((t) => ({ ref: refOf.get(t.id), name: t.name, isNew: newTagIds.has(t.id) })),
    excludedPairs,
    max: MAX_CANDIDATES,
  });

  // 목록에 없는 번호, 자기 자신, 새 개념이 없는 쌍, 이미 있는 쌍, 중복은 버린다
  const candidates = [];
  const seen = new Set();
  for (const { a, b } of stage1.candidates) {
    const x = byRef.get(a);
    const y = byRef.get(b);
    if (!x || !y || x.id === y.id) continue;
    if (!newTagIds.has(x.id) && !newTagIds.has(y.id)) continue;
    const key = pairKey(x.id, y.id);
    if (existingKeys.has(key) || seen.has(key)) continue;
    seen.add(key);
    candidates.push({ x, y });
    if (candidates.length >= MAX_CANDIDATES) break;
  }

  const run = { userId, scrap, stage1: stage1.usage, stage2: null, candidates: candidates.length, created: 0 };
  if (!candidates.length) {
    await evalService.recordRelationRun(run);
    return 0;
  }

  // ----- 2단계: 후보 쌍의 근거 스크랩을 모아 근거 확인 -----
  const relevantTagIds = new Set(candidates.flatMap(({ x, y }) => [x.id, y.id]));
  const tagNames = new Map(allTags.filter((t) => relevantTagIds.has(t.id)).map((t) => [t.id, t.name]));
  const otherTagIds = [...relevantTagIds].filter((id) => !newTagIds.has(id));

  const scraps = new Map();
  const add = (s) => scraps.has(s.key) || scraps.set(s.key, s);
  add(isArticle ? articleToScrap(saved, tagNames) : bookToScrap(saved, tagNames));
  for (const tagId of otherTagIds) {
    // 방금 저장한 스크랩은 이미 넣었으므로 뺀다
    const notSaved = { id: { not: saved.id } };
    const [articles, books] = await Promise.all([
      prisma.article.findMany({
        where: { userId, ...(isArticle && notSaved), articleTags: { some: { tagId } } },
        select: { ...ARTICLE_SELECT, createdAt: true },
        orderBy: { createdAt: 'desc' },
        take: SCRAPS_PER_TAG,
      }),
      prisma.bookScrap.findMany({
        where: { userId, ...(!isArticle && notSaved), bookTags: { some: { tagId } } },
        select: { ...BOOK_SELECT, createdAt: true },
        orderBy: { createdAt: 'desc' },
        take: SCRAPS_PER_TAG,
      }),
    ]);
    // 기사·책을 합쳐 최근 것부터 SCRAPS_PER_TAG개
    const recent = [
      ...articles.map((a) => ({ at: a.createdAt, s: articleToScrap(a, tagNames) })),
      ...books.map((b) => ({ at: b.createdAt, s: bookToScrap(b, tagNames) })),
    ]
      .sort((p, q) => q.at - p.at)
      .slice(0, SCRAPS_PER_TAG);
    recent.forEach(({ s }) => add(s));
  }

  const scrapList = [...scraps.values()].map((s, i) => ({ ...s, ref: `S${i + 1}` }));
  const scrapByRef = new Map(scrapList.map((s) => [s.ref, s]));
  const candidateByKey = new Map(candidates.map((c) => [pairKey(c.x.id, c.y.id), c]));

  const stage2 = await claudeService.confirmRelations({
    candidates: candidates.map(({ x, y }) => ({ a: refOf.get(x.id), b: refOf.get(y.id), aName: x.name, bName: y.name })),
    scraps: scrapList.map(({ ref, text }) => ({ ref, text })),
    max: MAX_SUGGESTIONS,
  });
  run.stage2 = stage2.usage;

  // 서버 검증: 후보에 있던 쌍인지, 근거 스크랩이 내 것이고 두 개념이 각각 실제로 붙어 있는지 (doc/plan.md 1-3)
  let created = 0;
  for (const r of stage2.relations.slice(0, MAX_SUGGESTIONS)) {
    const x = byRef.get(r.a);
    const y = byRef.get(r.b);
    if (!x || !y) continue;
    const key = pairKey(x.id, y.id);
    if (!candidateByKey.has(key) || existingKeys.has(key)) continue;

    const evidence = [...new Set(r.evidence)].map((ref) => scrapByRef.get(ref)).filter(Boolean);
    const coversX = evidence.some((s) => s.tagIds.has(x.id));
    const coversY = evidence.some((s) => s.tagIds.has(y.id));
    if (!evidence.length || !coversX || !coversY || !r.reason.trim()) {
      console.log(`[관계 제안] 근거 검증 실패로 버림: ${x.name}—${y.name}`);
      continue;
    }
    // 두 개념 중 하나라도 붙은 스크랩만 근거로 남긴다
    const kept = evidence.filter((s) => s.tagIds.has(x.id) || s.tagIds.has(y.id));

    const [tagAId, tagBId] = orderPair(x.id, y.id);
    try {
      await prisma.conceptRelation.create({
        data: {
          tagAId,
          tagBId,
          reason: r.reason.trim(),
          status: 'SUGGESTED',
          evidences: {
            create: kept.map((s) => (s.articleId ? { articleId: s.articleId } : { bookScrapId: s.bookScrapId })),
          },
        },
      });
      existingKeys.add(key);
      created++;
    } catch (err) {
      // 다른 제안 작업이 같은 쌍을 먼저 만든 경우
      if (err.code !== 'P2002') throw err;
    }
  }

  run.created = created;
  console.log(`[관계 제안] 후보 ${candidates.length}쌍 → 제안 ${created}개`);
  await evalService.recordRelationRun(run);
  return created;
}

// 스크랩 저장 응답을 기다리게 하지 않도록 서버 프로세스 안에서 이어서 실행한다.
// 서버가 그 사이 재시작되면 이 제안은 유실된다 (제안은 다시 만들 수 있는 데이터라 MVP에서 감수, doc/plan.md 5장).
// 작업 큐(Redis + BullMQ)로 바꿀 수 있도록 호출 지점은 이 함수 하나로 모은다.
function suggestInBackground(userId, scrap) {
  if (process.env.RELATION_SUGGEST === 'off') return;
  suggestRelations(userId, scrap).catch((err) => console.error(`[관계 제안] 실패: ${err.message}`));
}

module.exports = { suggestRelations, suggestInBackground, MAX_CANDIDATES, MAX_SUGGESTIONS, SCRAPS_PER_TAG };
