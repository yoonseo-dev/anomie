const { rateLimit } = require('express-rate-limit');

const HOUR = 60 * 60 * 1000;

// 분석 호출(Claude·OCR 비용)의 사용자별 상한. 기사·책 분석을 합쳐 센다 (10-29 결정)
const ANALYZE_PER_HOUR = 20;
const ANALYZE_PER_DAY = 60;

// 메모리에 센다. 서버를 여러 대로 늘리면 Redis 등 공용 저장소로 바꿔야 한다 (doc/plan.md 9장)
function limiter({ windowMs, limit, keyGenerator, message }) {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    ...(keyGenerator && { keyGenerator }),
    // 검증 실패(400)·중복(409) 같은 실패 응답은 비용이 들지 않으므로 세지 않는다
    skipFailedRequests: true,
    handler: (req, res, next, options) => res.status(options.statusCode).json({ message }),
  });
}

// authMiddleware 뒤에 둔다 (req.user가 있어야 사용자별로 센다)
function analyzeLimiter({ perHour = ANALYZE_PER_HOUR, perDay = ANALYZE_PER_DAY } = {}) {
  const byUser = (req) => req.user.userId;
  const message = `분석 요청이 너무 많습니다. 1시간에 ${perHour}회, 하루 ${perDay}회까지 분석할 수 있습니다.`;
  return [
    limiter({ windowMs: HOUR, limit: perHour, keyGenerator: byUser, message }),
    limiter({ windowMs: 24 * HOUR, limit: perDay, keyGenerator: byUser, message }),
  ];
}

// 로그인(비밀번호 대입 방지)·토큰 갱신의 IP별 상한. 성공한 요청은 세지 않도록 실패만 센다
function authLimiter({ limit = 10, windowMs = 15 * 60 * 1000 } = {}) {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    skipSuccessfulRequests: true,
    handler: (req, res, next, options) =>
      res.status(options.statusCode).json({ message: '시도가 너무 많습니다. 잠시 후 다시 시도해주세요.' }),
  });
}

// 기사·책 분석 라우트가 함께 쓰는 하나의 카운터 (합산)
const analyzeLimit = analyzeLimiter();

module.exports = { analyzeLimit, analyzeLimiter, authLimiter, ANALYZE_PER_HOUR, ANALYZE_PER_DAY };
