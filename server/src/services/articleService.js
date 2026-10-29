const prisma = require('../prisma');
const crawlerService = require('./crawlerService');
const claudeService = require('./claudeService');
const evalService = require('./evalService');
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
