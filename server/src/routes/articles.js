const { Router } = require('express');
const authMiddleware = require('../middleware/auth');
const prisma = require('../prisma');
const { crawlArticle } = require('../services/crawlerService');
const { analyzeArticleTags } = require('../services/claudeService');
const { saveArticle } = require('../services/articleService');

const router = Router();

// GET /articles - 내 스크랩 목록 조회 (최신순, 20개 페이지네이션, publisher 필터 지원)
router.get('/', authMiddleware, async (req, res, next) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const { publisher } = req.query;

    const where = { userId: req.user.userId };
    if (publisher) {
      // publisher는 URL 도메인 기준으로 매칭 (예: chosun, yna, hani)
      where.url = { contains: publisher, mode: 'insensitive' };
    }

    const articles = await prisma.article.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * 20,
      take: 20,
      include: {
        articleTags: {
          include: { tag: true },
        },
      },
    });

    res.json(articles);
  } catch (err) {
    next(err);
  }
});

// GET /articles/:id - 기사 상세 조회 (본인 기사만, 태그·reason·description 포함)
router.get('/:id', authMiddleware, async (req, res, next) => {
  try {
    const article = await prisma.article.findUnique({
      where: { id: req.params.id },
      include: {
        articleTags: {
          include: { tag: true },
        },
      },
    });

    if (!article) {
      return res.status(404).json({ message: '기사를 찾을 수 없습니다.' });
    }
    if (article.userId !== req.user.userId) {
      return res.status(403).json({ message: '접근 권한이 없습니다.' });
    }

    res.json(article);
  } catch (err) {
    next(err);
  }
});

// DELETE /articles/:id - 기사 삭제 (본인 기사만, ArticleTag 함께 삭제)
router.delete('/:id', authMiddleware, async (req, res, next) => {
  try {
    const article = await prisma.article.findUnique({
      where: { id: req.params.id },
    });

    if (!article) {
      return res.status(404).json({ message: '기사를 찾을 수 없습니다.' });
    }
    if (article.userId !== req.user.userId) {
      return res.status(403).json({ message: '접근 권한이 없습니다.' });
    }

    await prisma.articleTag.deleteMany({ where: { articleId: article.id } });
    await prisma.article.delete({ where: { id: article.id } });

    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

// POST /articles - URL 스크랩 → Claude 태그 분석 → DB 저장
router.post('/', authMiddleware, async (req, res, next) => {
  try {
    const { url } = req.body;
    if (!url) {
      return res.status(400).json({ message: 'url은 필수입니다.' });
    }

    const existing = await prisma.article.findUnique({
      where: { userId_url: { userId: req.user.userId, url } },
      select: { id: true },
    });
    if (existing) {
      return res.status(409).json({ message: '이미 스크랩한 기사입니다.', articleId: existing.id });
    }

    const crawled = await crawlArticle(url);

    console.log(`[크롤링] title: "${crawled.title}" | content 길이: ${crawled.content.length}자`);

    if (!crawled.content || crawled.content.length < 100) {
      return res.status(400).json({ error: '기사 본문을 추출할 수 없습니다. 동적 페이지이거나 접근이 제한된 기사일 수 있습니다.' });
    }

    if (crawled.content.length > 5000) {
      return res.status(400).json({ error: '본문이 너무 긴 기사는 지원하지 않습니다.' });
    }

    const { tags, commentary, framing, rhetoric, stakeholders, values } = await analyzeArticleTags(
      `제목: ${crawled.title}\n\n${crawled.content}`
    );

    console.log(`[Claude] tags 개수: ${tags?.length ?? 0}`);

    const article = await saveArticle({ url, userId: req.user.userId, crawled, tags, commentary, framing, rhetoric, stakeholders, values });

    res.status(201).json(article);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
