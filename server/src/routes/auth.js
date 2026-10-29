const { Router } = require('express');
const { signup, login, refresh, logout } = require('../services/authService');
const { authLimiter } = require('../middleware/rateLimit');
const { readString } = require('../utils/validate');

const router = Router();

const loginLimit = authLimiter();
const refreshLimit = authLimiter({ limit: 30 });

// 간단한 형식 검사. 실제 주소인지는 확인하지 않는다
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function readEmail(body, errors) {
  const email = readString(body, 'email', { max: 254 }, errors);
  if (email && !EMAIL_PATTERN.test(email)) errors.push('email 형식이 올바르지 않습니다.');
  return email?.trim().toLowerCase() ?? null;
}

function badRequest(res, errors) {
  return res.status(400).json({ message: errors[0], errors });
}

// POST /auth/signup - 회원가입
router.post('/signup', async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const errors = [];
    const email = readEmail(body, errors);
    // bcrypt는 72바이트까지만 쓰므로 그 이상은 받지 않는다
    const password = readString(body, 'password', { min: 8, max: 72 }, errors);
    const nickname = readString(body, 'nickname', { max: 30 }, errors);
    if (password && Buffer.byteLength(password) > 72) errors.push('password가 너무 깁니다.');
    if (errors.length) return badRequest(res, errors);

    const user = await signup({ email, password, nickname: nickname.trim() });
    res.status(201).json({ message: '회원가입 성공', user });
  } catch (err) {
    next(err);
  }
});

// POST /auth/login - 로그인 → { accessToken(15분), refreshToken(30일), user }
router.post('/login', loginLimit, async (req, res, next) => {
  try {
    const body = req.body ?? {};
    const errors = [];
    const email = readEmail(body, errors);
    const password = readString(body, 'password', { max: 72 }, errors);
    if (errors.length) return badRequest(res, errors);

    res.json(await login({ email, password }));
  } catch (err) {
    next(err);
  }
});

// POST /auth/refresh - { refreshToken } → 새 { accessToken, refreshToken }. 이전 refreshToken은 더 쓸 수 없다
router.post('/refresh', refreshLimit, async (req, res, next) => {
  try {
    const errors = [];
    const refreshToken = readString(req.body ?? {}, 'refreshToken', { max: 200 }, errors);
    if (errors.length) return badRequest(res, errors);

    res.json(await refresh(refreshToken));
  } catch (err) {
    next(err);
  }
});

// POST /auth/logout - { refreshToken } → 이 기기의 로그인을 끝낸다 (Access 토큰은 만료(15분)까지 남는다)
router.post('/logout', async (req, res, next) => {
  try {
    const errors = [];
    const refreshToken = readString(req.body ?? {}, 'refreshToken', { max: 200 }, errors);
    if (errors.length) return badRequest(res, errors);

    await logout(refreshToken);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

module.exports = router;
