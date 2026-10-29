const { Router } = require('express');
const authMiddleware = require('../middleware/auth');
const prisma = require('../prisma');
const { analyzeArticle, saveArticle, ARTICLE_INCLUDE, MIN_CONTENT_LENGTH, MAX_CONTENT_LENGTH } = require('../services/articleService');

const router = Router();

const MAX_TAGS = 10;

// 문자열 필드 하나를 검사한다. 비어 있으면 optional일 때 null, 아니면 에러.
function readString(body, key, { max, min = 1, optional = false }, errors) {
  const value = body[key];
  if (value === undefined || value === null || value === '') {
    if (!optional) errors.push(`${key}은(는) 필수입니다.`);
    return null;
  }
  if (typeof value !== 'string') {
    errors.push(`${key}은(는) 문자열이어야 합니다.`);
    return null;
  }
  if (value.length < min || value.length > max) {
    errors.push(`${key}은(는) ${min}~${max}자여야 합니다.`);
  }
  return value;
}

function isHttpUrl(value) {
  try {
    const { protocol } = new URL(value);
    return protocol === 'http:' || protocol === 'https:';
  } catch {
    return false;
  }
}

function readUrl(body, errors) {
  const url = readString(body, 'url', { max: 2048 }, errors);
  if (url && !isHttpUrl(url)) errors.push('url은 http 또는 https 주소여야 합니다.');
  return url;
}

// POST /articles 요청 본문을 검사해 저장할 값만 골라낸다.
// 클라이언트가 보관하던 분석 결과가 그대로 돌아오므로 길이와 형식을 모두 다시 확인한다.
function parseSaveBody(body) {
  const errors = [];
  const url = readUrl(body, errors);
  const article = {
    url,
    title: readString(body, 'title', { max: 300 }, errors),
    publisher: readString(body, 'publisher', { max: 100, optional: true }, errors),
    thumbnailUrl: readString(body, 'thumbnailUrl', { max: 2048, optional: true }, errors),
    content: readString(body, 'content', { min: MIN_CONTENT_LENGTH, max: MAX_CONTENT_LENGTH }, errors),
    summary: readString(body, 'summary', { max: 1000, optional: true }, errors) ?? '',
    commentary: readString(body, 'commentary', { max: 2000, optional: true }, errors),
    framing: readString(body, 'framing', { max: 2000, optional: true }, errors),
    rhetoric: readString(body, 'rhetoric', { max: 2000, optional: true }, errors),
    stakeholders: readString(body, 'stakeholders', { max: 2000, optional: true }, errors),
    values: readString(body, 'values', { max: 2000, optional: true }, errors),
    publishedAt: null,
  };

  if (body.publishedAt) {
    const date = new Date(body.publishedAt);
    if (isNaN(date.getTime())) errors.push('publishedAt은 날짜 형식이어야 합니다.');
    else article.publishedAt = date;
  }

  const tags = [];
  if (!Array.isArray(body.tags) || body.tags.length < 1 || body.tags.length > MAX_TAGS) {
    errors.push(`tags는 1~${MAX_TAGS}개의 배열이어야 합니다.`);
  } else {
    body.tags.forEach((raw, i) => {
      const tagErrors = [];
      const t = raw && typeof raw === 'object' ? raw : {};
      const tag = {
        reason: readString(t, 'reason', { max: 500 }, tagErrors),
        explanation: readString(t, 'explanation', { max: 2000, optional: true }, tagErrors) ?? '',
      };
      if (t.tagId) {
        // 기존 태그: 이름·설명은 이미 DB에 있으므로 받지 않는다
        tag.tagId = readString(t, 'tagId', { max: 36 }, tagErrors);
      } else {
        tag.name = readString(t, 'name', { max: 50 }, tagErrors);
        tag.category = readString(t, 'category', { max: 50, optional: true }, tagErrors);
        tag.description = readString(t, 'description', { max: 3000, optional: true }, tagErrors);
      }
      errors.push(...tagErrors.map((e) => `tags[${i}].${e}`));
      tags.push(tag);
    });
  }

  return { errors, article, tags };
}

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
      include: ARTICLE_INCLUDE,
    });

    res.json(articles);
  } catch (err) {
    next(err);
  }
});

// POST /articles/analyze - URL 크롤링 → Claude 태그 제안. 저장하지 않고 결과만 돌려준다.
router.post('/analyze', authMiddleware, async (req, res, next) => {
  try {
    const errors = [];
    const url = readUrl(req.body ?? {}, errors);
    if (errors.length) {
      return res.status(400).json({ message: errors[0], errors });
    }

    const analysis = await analyzeArticle({ userId: req.user.userId, url });
    res.json(analysis);
  } catch (err) {
    if (err.status === 409) {
      return res.status(409).json({ message: err.message, articleId: err.articleId });
    }
    next(err);
  }
});

// GET /articles/:id - 기사 상세 조회 (본인 기사만, 태그·reason·description 포함)
router.get('/:id', authMiddleware, async (req, res, next) => {
  try {
    const article = await prisma.article.findUnique({
      where: { id: req.params.id },
      include: ARTICLE_INCLUDE,
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

// POST /articles - 사용자가 승인한 분석 결과(기사 + 태그)를 저장한다
// tags[]: 기존 태그는 { tagId, reason, explanation }, 새 태그는 { name, category, description, reason, explanation }
router.post('/', authMiddleware, async (req, res, next) => {
  try {
    const { errors, article, tags } = parseSaveBody(req.body ?? {});
    if (errors.length) {
      return res.status(400).json({ message: errors[0], errors });
    }

    const saved = await saveArticle({ userId: req.user.userId, article, tags });
    res.status(201).json(saved);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
