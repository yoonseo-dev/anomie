require('dotenv/config');
const express = require('express');
const authRouter = require('./routes/auth');
const articlesRouter = require('./routes/articles');

const app = express();

app.use(express.json());

// 인증 관련 라우터 (/auth/signup, /auth/login)
app.use('/auth', authRouter);

// 뉴스 스크랩 라우터 (/articles)
app.use('/articles', articlesRouter);

// 전역 에러 핸들러
app.use((err, req, res, next) => {
  const status = err.status || 500;
  res.status(status).json({ message: err.message || '서버 오류가 발생했습니다.' });
});

module.exports = app;
