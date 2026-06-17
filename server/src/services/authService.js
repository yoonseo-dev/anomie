const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const prisma = require('../prisma');

const SALT_ROUNDS = 10;
const TOKEN_EXPIRES_IN = '7d'; // Access Token 만료 기간 (7일)

// 회원가입 - 이메일 중복 확인 후 비밀번호를 bcrypt로 암호화하여 저장
async function signup({ email, password, nickname }) {
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    const error = new Error('이미 사용 중인 이메일입니다.');
    error.status = 409;
    throw error;
  }

  const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);
  const user = await prisma.user.create({
    data: { email, password: hashedPassword, nickname },
    select: { id: true, email: true, nickname: true, createdAt: true },
  });

  return user;
}

// 로그인 - 이메일/비밀번호 검증 후 JWT Access Token 발급
async function login({ email, password }) {
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    // 이메일 존재 여부를 노출하지 않기 위해 동일한 메시지 사용
    const error = new Error('이메일 또는 비밀번호가 올바르지 않습니다.');
    error.status = 401;
    throw error;
  }

  const isMatch = await bcrypt.compare(password, user.password);
  if (!isMatch) {
    const error = new Error('이메일 또는 비밀번호가 올바르지 않습니다.');
    error.status = 401;
    throw error;
  }

  const accessToken = jwt.sign(
    { userId: user.id, email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: TOKEN_EXPIRES_IN }
  );

  return {
    accessToken,
    user: { id: user.id, email: user.email, nickname: user.nickname },
  };
}

module.exports = { signup, login };
