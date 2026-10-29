const prisma = require('../prisma');
const crawlerService = require('./crawlerService');
const claudeService = require('./claudeService');
const httpError = require('../utils/httpError');

const MIN_CONTENT_LENGTH = 100;
const MAX_CONTENT_LENGTH = 5000;

const ARTICLE_INCLUDE = {
  articleTags: {
    include: { tag: true },
  },
};

async function ensureNotScrapped(userId, url) {
  const existing = await prisma.article.findUnique({
    where: { userId_url: { userId, url } },
    select: { id: true },
  });
  if (existing) {
    const error = httpError(409, '이미 스크랩한 기사입니다.');
    error.articleId = existing.id;
    throw error;
  }
}

// URL을 크롤링하고 Claude로 분석해 태그 제안을 돌려준다. DB에는 저장하지 않는다.
// 클라이언트가 결과를 들고 있다가 사용자가 승인한 태그와 함께 saveArticle로 보낸다.
async function analyzeArticle({ userId, url }) {
  await ensureNotScrapped(userId, url);

  const crawled = await crawlerService.crawlArticle(url);
  console.log(`[크롤링] title: "${crawled.title}" | content 길이: ${crawled.content.length}자`);

  if (!crawled.content || crawled.content.length < MIN_CONTENT_LENGTH) {
    throw httpError(400, '기사 본문을 추출할 수 없습니다. 동적 페이지이거나 접근이 제한된 기사일 수 있습니다.');
  }
  if (crawled.content.length > MAX_CONTENT_LENGTH) {
    throw httpError(400, '본문이 너무 긴 기사는 지원하지 않습니다.');
  }

  const analysis = await claudeService.analyzeArticleTags(`제목: ${crawled.title}\n\n${crawled.content}`);
  const tags = analysis.tags ?? [];
  console.log(`[Claude] tags 개수: ${tags.length}`);

  return {
    url,
    title: crawled.title,
    publisher: crawled.publisher,
    thumbnailUrl: crawled.thumbnailUrl,
    publishedAt: crawled.publishedAt,
    content: crawled.content,
    summary: crawled.summary,
    commentary: analysis.commentary ?? null,
    framing: analysis.framing ?? null,
    rhetoric: analysis.rhetoric ?? null,
    stakeholders: analysis.stakeholders ?? null,
    values: analysis.values ?? null,
    tags: tags.map((t) => ({
      name: t.name,
      category: t.category ?? null,
      description: t.description ?? null,
      reason: t.reason,
      explanation: t.explanation ?? '',
    })),
  };
}

// 승인된 태그를 실제 Tag 행으로 바꾼다. tagId는 본인 태그인지 확인하고, 새 이름은 만든다.
// 새 이름이 이미 내 태그에 있으면 그 태그를 쓴다 (같은 이름을 두 번 만들 수 없으므로).
async function resolveTags(tx, userId, tags) {
  const ids = tags.filter((t) => t.tagId).map((t) => t.tagId);
  const owned = await tx.tag.findMany({
    where: { userId, id: { in: ids } },
    select: { id: true },
  });
  if (owned.length !== new Set(ids).size) {
    throw httpError(400, '존재하지 않거나 내 것이 아닌 태그가 있습니다.');
  }

  const resolved = [];
  for (const t of tags) {
    let tagId = t.tagId;
    if (!tagId) {
      const tag = await tx.tag.upsert({
        where: { userId_name: { userId, name: t.name } },
        update: {},
        create: {
          userId,
          name: t.name,
          category: t.category,
          description: t.description,
        },
        select: { id: true },
      });
      tagId = tag.id;
    }
    resolved.push({ tagId, reason: t.reason, explanation: t.explanation });
  }

  if (new Set(resolved.map((r) => r.tagId)).size !== resolved.length) {
    throw httpError(400, '같은 태그가 두 번 들어 있습니다.');
  }
  return resolved;
}

// 사용자가 승인한 분석 결과를 기사·태그·ArticleTag로 한 번에 저장한다.
async function saveArticle({ userId, article, tags }) {
  try {
    const saved = await prisma.$transaction(async (tx) => {
      const resolved = await resolveTags(tx, userId, tags);
      return tx.article.create({
        data: {
          ...article,
          userId,
          articleTags: { create: resolved },
        },
        include: ARTICLE_INCLUDE,
      });
    });
    return saved;
  } catch (err) {
    // 분석과 저장 사이에 같은 URL이 먼저 저장된 경우
    if (err.code === 'P2002' && err.meta?.modelName === 'Article') {
      throw httpError(409, '이미 스크랩한 기사입니다.');
    }
    throw err;
  }
}

module.exports = { analyzeArticle, saveArticle, ARTICLE_INCLUDE, MIN_CONTENT_LENGTH, MAX_CONTENT_LENGTH };
