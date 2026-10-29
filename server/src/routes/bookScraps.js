const { Router } = require('express');
const multer = require('multer');
const authMiddleware = require('../middleware/auth');
const prisma = require('../prisma');
const { analyzeBookPage, saveBookScrap, deleteBookScrap, BOOK_SCRAP_INCLUDE } = require('../services/bookScrapService');
const { readString, readInt, readTags } = require('../utils/validate');
const imageInfo = require('../utils/imageInfo');

const router = Router();

const MAX_IMAGE_BYTES = 7 * 1024 * 1024; // Vision 요청 한도(base64 포함 약 10MB) 안쪽
const MIN_LONG_SIDE = 1000; // 이보다 작으면 작은 글자를 읽지 못한다 (10-29 실측)

// 사진은 메모리에서만 다루고 디스크에 쓰지 않는다
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_IMAGE_BYTES, files: 1 },
}).single('image');

function uploadImage(req, res, next) {
  upload(req, res, (err) => {
    if (!err) return next();
    if (err instanceof multer.MulterError) {
      const message =
        err.code === 'LIMIT_FILE_SIZE'
          ? `사진은 ${MAX_IMAGE_BYTES / 1024 / 1024}MB 이하여야 합니다.`
          : '사진은 image 필드에 한 장만 보내주세요.';
      return res.status(400).json({ message });
    }
    next(err);
  });
}

// 책 정보 (제목·저자·쪽수). analyze는 multipart 필드로, 저장은 JSON으로 온다.
function readBookFields(body, errors) {
  return {
    bookTitle: readString(body, 'bookTitle', { max: 200 }, errors),
    author: readString(body, 'author', { max: 100, optional: true }, errors),
    page: readInt(body, 'page', { min: 1, max: 100000, optional: true }, errors),
  };
}

// GET /book-scraps - 내 책 스크랩 목록 (최신순, 20개 페이지네이션)
router.get('/', authMiddleware, async (req, res, next) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const bookScraps = await prisma.bookScrap.findMany({
      where: { userId: req.user.userId },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * 20,
      take: 20,
      include: BOOK_SCRAP_INCLUDE,
    });
    res.json(bookScraps);
  } catch (err) {
    next(err);
  }
});

// POST /book-scraps/analyze - 책 페이지 사진 → OCR → Claude 태그·근거 문장 제안. 저장하지 않는다.
// multipart/form-data: image(JPEG/PNG/WebP), bookTitle, author?, page?
router.post('/analyze', authMiddleware, uploadImage, async (req, res, next) => {
  try {
    const errors = [];
    const book = readBookFields(req.body ?? {}, errors);

    if (!req.file) {
      errors.push('image(책 페이지 사진)는 필수입니다.');
    } else {
      const info = imageInfo(req.file.buffer);
      if (!info) {
        errors.push('사진은 JPEG, PNG, WebP 중 하나여야 합니다.');
      } else if (Math.max(info.width, info.height) < MIN_LONG_SIDE) {
        errors.push(`사진 해상도가 너무 낮습니다 (긴 변 ${MIN_LONG_SIDE}px 이상). 더 선명하게 다시 찍어주세요.`);
      }
    }
    if (errors.length) {
      return res.status(400).json({ message: errors[0], errors });
    }

    const analysis = await analyzeBookPage({ userId: req.user.userId, image: req.file.buffer, ...book });
    res.json(analysis);
  } catch (err) {
    next(err);
  }
});

// GET /book-scraps/:id - 책 스크랩 상세 (본인 것만, 태그·근거 문장 포함)
router.get('/:id', authMiddleware, async (req, res, next) => {
  try {
    const bookScrap = await prisma.bookScrap.findUnique({
      where: { id: req.params.id },
      include: BOOK_SCRAP_INCLUDE,
    });

    if (!bookScrap) {
      return res.status(404).json({ message: '책 스크랩을 찾을 수 없습니다.' });
    }
    if (bookScrap.userId !== req.user.userId) {
      return res.status(403).json({ message: '접근 권한이 없습니다.' });
    }

    res.json(bookScrap);
  } catch (err) {
    next(err);
  }
});

// DELETE /book-scraps/:id - 책 스크랩 삭제 (본인 것만). BookScrapTag와 근거가 사라진 관계(거절 제외)도 함께 삭제
router.delete('/:id', authMiddleware, async (req, res, next) => {
  try {
    await deleteBookScrap(req.user.userId, req.params.id);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

// POST /book-scraps - 사용자가 승인한 분석 결과(책 정보 + 태그·근거 문장)를 저장한다
// tags[]: 기존 태그는 { tagId, reason, explanation, excerpt }, 새 태그는 { name, category, description, reason, explanation, excerpt }
router.post('/', authMiddleware, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const errors = [];
    const bookScrap = {
      ...readBookFields(body, errors),
      summary: readString(body, 'summary', { max: 1000 }, errors),
    };
    const tags = readTags(body, errors, { withExcerpt: true });
    if (errors.length) {
      return res.status(400).json({ message: errors[0], errors });
    }

    const saved = await saveBookScrap({ userId: req.user.userId, bookScrap, tags });
    res.status(201).json(saved);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
