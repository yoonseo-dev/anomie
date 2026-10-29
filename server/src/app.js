require('dotenv/config');
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const authRouter = require('./routes/auth');
const articlesRouter = require('./routes/articles');
const bookScrapsRouter = require('./routes/bookScraps');
const conceptsRouter = require('./routes/concepts');
const relationsRouter = require('./routes/relations');

if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET이 설정되지 않았습니다 (server/.env).');
}

const app = express();

// 프록시(배포 환경의 로드밸런서 등) 뒤에서 실제 클라이언트 IP로 호출 제한을 세려면 TRUST_PROXY를 준다 (예: 1)
if (process.env.TRUST_PROXY) app.set('trust proxy', Number(process.env.TRUST_PROXY) || process.env.TRUST_PROXY);

// 보안 헤더 (X-Powered-By 제거 등). JSON API라 화면용 정책은 영향이 없다
app.use(helmet());

// CORS: 모바일 앱은 해당 없음. 웹 빌드에서 호출할 출처만 CORS_ORIGINS(쉼표로 구분)에 넣는다. 없으면 다른 출처를 허용하지 않는다
const corsOrigins = (process.env.CORS_ORIGINS ?? '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);
app.use(cors({ origin: corsOrigins.length ? corsOrigins : false }));

// 가장 큰 JSON 요청은 기사 저장(본문 5000자 + 분석 결과)이라 100kb면 충분하다. 사진은 multipart로 따로 받는다
app.use(express.json({ limit: '100kb' }));

// 인증 관련 라우터 (/auth/signup, /auth/login, /auth/refresh, /auth/logout)
app.use('/auth', authRouter);

// 뉴스 스크랩 라우터 (/articles)
app.use('/articles', articlesRouter);

// 책 스크랩 라우터 (/book-scraps)
app.use('/book-scraps', bookScrapsRouter);

// 개념(태그)·마인드맵 라우터 (/concepts, /concepts/graph)
app.use('/concepts', conceptsRouter);

// 개념 간 관계 관리 라우터 (/relations)
app.use('/relations', relationsRouter);

// 전역 에러 핸들러. 서버 내부 오류(500)는 메시지를 숨기고 로그에만 남긴다 (DB 오류 등이 밖으로 새지 않게)
app.use((err, req, res, next) => {
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ message: '요청 본문이 올바른 JSON이 아닙니다.' });
  }
  if (err.type === 'entity.too.large') {
    return res.status(413).json({ message: '요청 본문이 너무 큽니다.' });
  }

  const status = err.status || 500;
  if (status >= 500) {
    console.error(`[오류] ${req.method} ${req.originalUrl}`, err);
    // 서비스가 일부러 만든 502/503 안내(분석 실패 등)는 그대로 보여 준다
    const message = err.status ? err.message : '서버 오류가 발생했습니다.';
    return res.status(status).json({ message });
  }
  res.status(status).json({ message: err.message });
});

module.exports = app;
