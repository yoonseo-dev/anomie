const prisma = require('../prisma');
const crawlerService = require('./crawlerService');
const claudeService = require('./claudeService');
const evalService = require('./evalService');
const relationService = require('./relationService');
const relationSuggestService = require('./relationSuggestService');
const { findExistingTags, toSuggestedTags, resolveTags } = require('./tagService');
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

  const existingTags = await findExistingTags(userId);
  const articleText = `제목: ${crawled.title}\n\n${crawled.content}`;
  const analysis = await claudeService.analyzeArticleTags(articleText, existingTags);

  const result = {
    url,
    title: crawled.title,
    publisher: crawled.publisher,
    thumbnailUrl: crawled.thumbnailUrl,
    publishedAt: crawled.publishedAt,
    content: crawled.content,
    // 관계 제안 때 원문 대신 넘기는 요약. Claude 요약이 비면 크롤링한 소개 문구를 쓴다
    summary: analysis.summary || crawled.summary,
    commentary: analysis.commentary ?? null,
    framing: analysis.framing ?? null,
    rhetoric: analysis.rhetoric ?? null,
    stakeholders: analysis.stakeholders ?? null,
    values: analysis.values ?? null,
    tags: toSuggestedTags(analysis.tags, existingTags),
  };

  // 비용·품질 기록 (응답 뒤 백그라운드에서 채점)
  evalService.recordInBackground({
    kind: 'article',
    userId,
    input: { url, title: crawled.title },
    source: articleText,
    existingTags,
    rawTags: analysis.tags,
    result,
    usage: analysis.usage,
  });
  return result;
}

// 사용자가 승인한 분석 결과를 기사·태그·ArticleTag로 한 번에 저장한다.
// 저장은 바로 끝내고, 관계 제안은 응답 뒤 백그라운드에서 만든다 (doc/plan.md 1-4)
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
    relationSuggestService.suggestInBackground(userId, { kind: 'article', id: saved.id });
    return saved;
  } catch (err) {
    // 분석과 저장 사이에 같은 URL이 먼저 저장된 경우
    if (err.code === 'P2002' && err.meta?.modelName === 'Article') {
      throw httpError(409, '이미 스크랩한 기사입니다.');
    }
    throw err;
  }
}

// 기사 삭제. ArticleTag·근거 행은 Cascade로 지워지고, 근거가 0개가 된 관계(거절 제외)도 같은 트랜잭션에서 지운다
async function deleteArticle(userId, id) {
  const article = await prisma.article.findUnique({ where: { id }, select: { userId: true } });
  if (!article) throw httpError(404, '기사를 찾을 수 없습니다.');
  if (article.userId !== userId) throw httpError(403, '접근 권한이 없습니다.');

  await prisma.$transaction(async (tx) => {
    const relationIds = await relationService.relationIdsByEvidence(tx, { articleId: id });
    await tx.article.delete({ where: { id } });
    await relationService.removeOrphanRelations(tx, relationIds);
  });
}

module.exports = { analyzeArticle, saveArticle, deleteArticle, ARTICLE_INCLUDE, MIN_CONTENT_LENGTH, MAX_CONTENT_LENGTH };
