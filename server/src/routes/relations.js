const { Router } = require('express');
const authMiddleware = require('../middleware/auth');
const relationService = require('../services/relationService');
const { readString } = require('../utils/validate');

const router = Router();
router.use(authMiddleware);

const STATUSES = ['SUGGESTED', 'APPROVED', 'REJECTED'];

// GET /relations?status=SUGGESTED - 내 관계 목록 (관리 화면 관계 탭). 근거 스크랩 포함
router.get('/', async (req, res, next) => {
  try {
    const { status } = req.query;
    if (status && !STATUSES.includes(status)) {
      return res.status(400).json({ message: `status는 ${STATUSES.join(', ')} 중 하나여야 합니다.` });
    }
    res.json(await relationService.listRelations(req.user.userId, { status }));
  } catch (err) {
    next(err);
  }
});

// GET /relations/:id - 관계 상세 (근거 스크랩 포함)
router.get('/:id', async (req, res, next) => {
  try {
    res.json(await relationService.getRelation(req.user.userId, req.params.id));
  } catch (err) {
    next(err);
  }
});

// PATCH /relations/:id - { status?, reason? }
// 승인 = APPROVED, 제안 거절·연결 끊기 = REJECTED (지우지 않고 보존해 재제안을 막음), 되돌리기 = 이전 상태로
router.patch('/:id', async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const errors = [];
    if (body.status !== undefined && !STATUSES.includes(body.status)) {
      errors.push(`status는 ${STATUSES.join(', ')} 중 하나여야 합니다.`);
    }
    const reason = body.reason === undefined ? undefined : readString(body, 'reason', { max: 500 }, errors);
    if (body.status === undefined && body.reason === undefined) errors.push('status 또는 reason이 필요합니다.');
    if (errors.length) return res.status(400).json({ message: errors[0], errors });

    res.json(await relationService.updateRelation(req.user.userId, req.params.id, { status: body.status, reason }));
  } catch (err) {
    next(err);
  }
});

module.exports = router;
