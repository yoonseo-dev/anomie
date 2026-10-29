require('dotenv/config');
const express = require('express');
const authRouter = require('./routes/auth');
const articlesRouter = require('./routes/articles');
const bookScrapsRouter = require('./routes/bookScraps');
const conceptsRouter = require('./routes/concepts');
const relationsRouter = require('./routes/relations');

const app = express();

app.use(express.json());

// 인증 관련 라우터 (/auth/signup, /auth/login)
app.use('/auth', authRouter);

// 뉴스 스크랩 라우터 (/articles)
app.use('/articles', articlesRouter);

// 책 스크랩 라우터 (/book-scraps)
app.use('/book-scraps', bookScrapsRouter);

// 개념(태그)·마인드맵 라우터 (/concepts, /concepts/graph)
app.use('/concepts', conceptsRouter);

// 개념 간 관계 관리 라우터 (/relations)
app.use('/relations', relationsRouter);

// 전역 에러 핸들러
app.use((err, req, res, next) => {
  const status = err.status || 500;
  res.status(status).json({ message: err.message || '서버 오류가 발생했습니다.' });
});

module.exports = app;
