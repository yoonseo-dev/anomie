const crypto = require('crypto');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const prisma = require('../prisma');
const httpError = require('../utils/httpError');

const SALT_ROUNDS = 10;
const ACCESS_TOKEN_EXPIRES_IN = '15m'; // API 호출용. 짧게 두고 Refresh 토큰으로 갱신한다
const REFRESH_TOKEN_DAYS = 30; // 로그인 유지 기간. 갱신할 때마다 새로 30일

const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');

// 회원가입 - 이메일 중복 확인 후 비밀번호를 bcrypt로 암호화하여 저장
async function signup({ email, password, nickname }) {
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) throw httpError(409, '이미 사용 중인 이메일입니다.');

  const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);
  return prisma.user.create({
    data: { email, password: hashedPassword, nickname },
    select: { id: true, email: true, nickname: true, createdAt: true },
  });
}

function signAccessToken(user) {
  return jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET, {
    expiresIn: ACCESS_TOKEN_EXPIRES_IN,
    algorithm: 'HS256',
  });
}

// Refresh 토큰은 JWT가 아니라 임의 문자열이다. DB에는 해시만 남기므로 DB가 새도 토큰을 쓸 수 없다
async function issueRefreshToken(db, userId, familyId) {
  const token = crypto.randomBytes(48).toString('base64url');
  await db.refreshToken.create({
    data: {
      userId,
      familyId,
      tokenHash: sha256(token),
      expiresAt: new Date(Date.now() + REFRESH_TOKEN_DAYS * 24 * 60 * 60 * 1000),
    },
  });
  return token;
}

// 로그인 - 이메일/비밀번호 검증 후 Access 토큰(15분)과 Refresh 토큰(30일) 발급
async function login({ email, password }) {
  const user = await prisma.user.findUnique({ where: { email } });
  // 이메일 존재 여부를 노출하지 않기 위해 같은 메시지를 쓴다
  const isMatch = user && (await bcrypt.compare(password, user.password));
  if (!isMatch) throw httpError(401, '이메일 또는 비밀번호가 올바르지 않습니다.');

  const refreshToken = await issueRefreshToken(prisma, user.id, crypto.randomUUID());
  return {
    accessToken: signAccessToken(user),
    refreshToken,
    user: { id: user.id, email: user.email, nickname: user.nickname },
  };
}

const INVALID_REFRESH = '로그인이 만료되었습니다. 다시 로그인해주세요.';

// 토큰 갱신 - Refresh 토큰을 새 것으로 바꾸고(이전 것은 폐기) 새 Access 토큰을 발급한다.
// 이미 폐기된 토큰이 다시 오면 탈취된 것으로 보고 그 로그인(familyId)의 토큰을 모두 폐기한다.
async function refresh(refreshToken) {
  const stored = await prisma.refreshToken.findUnique({
    where: { tokenHash: sha256(refreshToken) },
    include: { user: { select: { id: true, email: true } } },
  });
  if (!stored) throw httpError(401, INVALID_REFRESH);

  if (stored.revokedAt) {
    // 트랜잭션 밖에서 폐기한다 (오류를 던져도 폐기는 남아야 한다)
    await revokeFamily(stored.familyId);
    console.warn(`[인증] 폐기된 Refresh 토큰 재사용 감지 → 로그인 묶음 폐기 (user ${stored.userId})`);
    throw httpError(401, INVALID_REFRESH);
  }
  if (stored.expiresAt < new Date()) throw httpError(401, INVALID_REFRESH);

  return prisma.$transaction(async (tx) => {
    // 동시에 같은 토큰으로 두 번 갱신하면 한쪽만 성공한다
    const { count } = await tx.refreshToken.updateMany({
      where: { id: stored.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    if (count === 0) throw httpError(401, INVALID_REFRESH);

    return {
      accessToken: signAccessToken(stored.user),
      refreshToken: await issueRefreshToken(tx, stored.userId, stored.familyId),
    };
  });
}

function revokeFamily(familyId) {
  return prisma.refreshToken.updateMany({
    where: { familyId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

// 로그아웃 - 이 기기의 로그인(familyId)에 속한 토큰을 모두 폐기한다. 모르는 토큰이어도 조용히 끝낸다
async function logout(refreshToken) {
  const stored = await prisma.refreshToken.findUnique({ where: { tokenHash: sha256(refreshToken) } });
  if (stored) await revokeFamily(stored.familyId);
}

module.exports = { signup, login, refresh, logout, ACCESS_TOKEN_EXPIRES_IN, REFRESH_TOKEN_DAYS };
