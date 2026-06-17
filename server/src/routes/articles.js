const { Router } = require('express');
const authMiddleware = require('../middleware/auth');
const prisma = require('../prisma');

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

module.exports = router;
