const { Router } = require('express');
const authMiddleware = require('../middleware/auth');
const conceptService = require('../services/conceptService');
const relationService = require('../services/relationService');
const { readString } = require('../utils/validate');

const router = Router();
router.use(authMiddleware);

const MAX_PREVIEW = 30;

// GET /concepts - 내 개념 목록 (관리 화면). 스크랩 수·승인 연결 수·제안 수 포함
router.get('/', async (req, res, next) => {
  try {
    res.json(await conceptService.listConcepts(req.user.userId));
  } catch (err) {
    next(err);
  }
});

// GET /concepts/graph - 마인드맵 그래프 { nodes, links } (거절한 관계 제외)
//   ?center=<개념 id>: 중심 개념과 직접 연결된 개념만 (마인드맵 기본 화면)
router.get('/graph', async (req, res, next) => {
  try {
    const { center } = req.query;
    const graph = center
      ? await relationService.centerGraph(req.user.userId, String(center))
      : await relationService.fullGraph(req.user.userId);
    res.json(graph);
  } catch (err) {
    next(err);
  }
});

// GET /concepts/graph/preview?limit=15 - 홈 미리보기 (최근 추가 + 연결 많은 개념)
router.get('/graph/preview', async (req, res, next) => {
  try {
    const limit = Math.min(MAX_PREVIEW, Math.max(1, parseInt(req.query.limit) || 15));
    res.json(await relationService.previewGraph(req.user.userId, limit));
  } catch (err) {
    next(err);
  }
});

// GET /concepts/:id - 개념 상세 (설명, 내 스크랩에서의 등장, 연결된 개념)
router.get('/:id', async (req, res, next) => {
  try {
    res.json(await conceptService.getConcept(req.user.userId, req.params.id));
  } catch (err) {
    next(err);
  }
});

// PATCH /concepts/:id - 설명 수정 { description }. 고치면 "AI 생성" 표시가 빠진다
router.patch('/:id', async (req, res, next) => {
  try {
    const errors = [];
    const description = readString(req.body ?? {}, 'description', { max: 3000 }, errors);
    if (errors.length) return res.status(400).json({ message: errors[0], errors });

    res.json(await conceptService.updateDescription(req.user.userId, req.params.id, description));
  } catch (err) {
    next(err);
  }
});

// DELETE /concepts/:id - 개념 삭제 (스크랩 연결·관계도 삭제, 스크랩은 남음)
router.delete('/:id', async (req, res, next) => {
  try {
    await conceptService.deleteConcept(req.user.userId, req.params.id);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

// POST /concepts/:id/merge - 이 개념을 { intoId } 개념에 합친다. 합친 개념의 상세를 돌려준다
router.post('/:id/merge', async (req, res, next) => {
  try {
    const errors = [];
    const intoId = readString(req.body ?? {}, 'intoId', { max: 36 }, errors);
    if (errors.length) return res.status(400).json({ message: errors[0], errors });

    res.json(await conceptService.mergeConcepts(req.user.userId, req.params.id, intoId));
  } catch (err) {
    next(err);
  }
});

module.exports = router;
