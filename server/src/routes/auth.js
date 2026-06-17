const { Router } = require('express');
const { signup, login } = require('../services/authService');

const router = Router();

// POST /auth/signup - 회원가입
router.post('/signup', async (req, res, next) => {
  try {
    const { email, password, nickname } = req.body;
    if (!email || !password || !nickname) {
      return res.status(400).json({ message: 'email, password, nickname은 필수입니다.' });
    }
    const user = await signup({ email, password, nickname });
    res.status(201).json({ message: '회원가입 성공', user });
  } catch (err) {
    next(err);
  }
});

// POST /auth/login - 로그인 (Access Token 발급)
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'email, password는 필수입니다.' });
    }
    const result = await login({ email, password });
    res.json(result);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
