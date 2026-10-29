const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const { prisma, startServer, request } = require('./helpers');

const uniqueEmail = () => `auth-${Date.now()}-${Math.random().toString(36).slice(2)}@anomie.test`;
const PASSWORD = 'correct-horse-1';

describe('인증: 회원가입·로그인·토큰 갱신·로그아웃', () => {
  let server;
  let call;
  const emails = [];

  // 가입 후 로그인까지 해서 { email, accessToken, refreshToken, user }를 돌려준다
  async function signupAndLogin() {
    const email = uniqueEmail();
    emails.push(email);
    await call('POST', '/auth/signup', { email, password: PASSWORD, nickname: '테스트' });
    const res = await call('POST', '/auth/login', { email, password: PASSWORD });
    return { email, ...res.body };
  }

  const authed = (token) => request(server.baseUrl, token);

  before(async () => {
    server = await startServer();
    call = request(server.baseUrl);
  });

  after(async () => {
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
    await server.close();
    await prisma.$disconnect();
  });

  test('회원가입은 이메일 형식·비밀번호 길이(8~72바이트)·닉네임을 확인한다', async () => {
    const cases = [
      { email: 'not-an-email', password: PASSWORD, nickname: 'a' },
      { email: uniqueEmail(), password: 'short', nickname: 'a' },
      { email: uniqueEmail(), password: '가'.repeat(30), nickname: 'a' }, // 30자지만 90바이트
      { email: uniqueEmail(), password: PASSWORD },
      { email: uniqueEmail(), password: 12345678, nickname: 'a' },
    ];
    for (const body of cases) {
      const res = await call('POST', '/auth/signup', body);
      assert.equal(res.status, 400, JSON.stringify(body));
      assert.ok(res.body.message);
    }
  });

  test('이메일은 소문자로 저장하고, 같은 이메일은 409', async () => {
    const email = uniqueEmail();
    emails.push(email);

    const res = await call('POST', '/auth/signup', { email: email.toUpperCase(), password: PASSWORD, nickname: '테스트' });
    const again = await call('POST', '/auth/signup', { email, password: PASSWORD, nickname: '테스트' });

    assert.equal(res.status, 201);
    assert.equal(res.body.user.email, email);
    assert.equal(res.body.user.password, undefined);
    assert.equal(again.status, 409);
  });

  test('로그인하면 15분짜리 Access 토큰과 Refresh 토큰을 주고, Access 토큰으로 API를 쓸 수 있다', async () => {
    const { accessToken, refreshToken, user } = await signupAndLogin();

    const { iat, exp, userId } = jwt.decode(accessToken);
    assert.equal(exp - iat, 15 * 60);
    assert.equal(userId, user.id);
    assert.ok(refreshToken.length >= 60);
    // DB에는 원문이 아니라 해시만 있다
    assert.equal(await prisma.refreshToken.count({ where: { tokenHash: refreshToken } }), 0);
    assert.equal(await prisma.refreshToken.count({ where: { userId: user.id } }), 1);

    assert.equal((await authed(accessToken)('GET', '/concepts')).status, 200);
  });

  test('틀린 비밀번호와 없는 이메일은 같은 401 메시지', async () => {
    const { email } = await signupAndLogin();

    const wrong = await call('POST', '/auth/login', { email, password: 'wrong-password' });
    const unknown = await call('POST', '/auth/login', { email: uniqueEmail(), password: 'wrong-password' });

    assert.equal(wrong.status, 401);
    assert.equal(unknown.status, 401);
    assert.equal(wrong.body.message, unknown.body.message);
  });

  test('갱신하면 새 토큰 쌍을 주고, 이전 Refresh 토큰은 더 쓸 수 없다', async () => {
    const first = await signupAndLogin();

    const refreshed = await call('POST', '/auth/refresh', { refreshToken: first.refreshToken });

    assert.equal(refreshed.status, 200);
    assert.notEqual(refreshed.body.refreshToken, first.refreshToken);
    assert.equal((await authed(refreshed.body.accessToken)('GET', '/concepts')).status, 200);
    // 새 토큰으로 한 번 더 갱신 가능
    const second = await call('POST', '/auth/refresh', { refreshToken: refreshed.body.refreshToken });
    assert.equal(second.status, 200);
  });

  test('폐기된 Refresh 토큰이 다시 오면(탈취 의심) 그 로그인의 토큰을 모두 무효로 만든다', async () => {
    const first = await signupAndLogin();
    const { body: rotated } = await call('POST', '/auth/refresh', { refreshToken: first.refreshToken });

    const reuse = await call('POST', '/auth/refresh', { refreshToken: first.refreshToken });
    const afterReuse = await call('POST', '/auth/refresh', { refreshToken: rotated.refreshToken });

    assert.equal(reuse.status, 401);
    assert.equal(afterReuse.status, 401); // 정상 사용자 쪽 최신 토큰도 무효 → 다시 로그인
  });

  test('로그아웃하면 그 기기의 Refresh 토큰만 무효가 되고, 다른 기기 로그인은 남는다', async () => {
    const phone = await signupAndLogin();
    const { body: tablet } = await call('POST', '/auth/login', { email: phone.email, password: PASSWORD });

    const res = await call('POST', '/auth/logout', { refreshToken: phone.refreshToken });

    assert.equal(res.status, 204);
    assert.equal((await call('POST', '/auth/refresh', { refreshToken: phone.refreshToken })).status, 401);
    assert.equal((await call('POST', '/auth/refresh', { refreshToken: tablet.refreshToken })).status, 200);
    // 모르는 토큰으로 로그아웃해도 조용히 끝난다
    assert.equal((await call('POST', '/auth/logout', { refreshToken: 'unknown' })).status, 204);
  });

  test('만료된 Refresh 토큰, 없는 토큰, 빈 요청은 거절한다', async () => {
    const { user, refreshToken } = await signupAndLogin();
    await prisma.refreshToken.updateMany({ where: { userId: user.id }, data: { expiresAt: new Date(Date.now() - 1000) } });

    assert.equal((await call('POST', '/auth/refresh', { refreshToken })).status, 401);
    assert.equal((await call('POST', '/auth/refresh', { refreshToken: 'unknown' })).status, 401);
    assert.equal((await call('POST', '/auth/refresh', {})).status, 400);
  });

  test('다른 비밀키나 다른 알고리즘으로 서명된 Access 토큰은 401', async () => {
    const { user } = await signupAndLogin();
    const payload = { userId: user.id, email: 'x' };

    const otherSecret = jwt.sign(payload, 'not-the-secret');
    const unsigned = jwt.sign(payload, null, { algorithm: 'none' });
    const expired = jwt.sign({ ...payload, exp: Math.floor(Date.now() / 1000) - 10 }, process.env.JWT_SECRET);

    for (const token of [otherSecret, unsigned, expired]) {
      assert.equal((await authed(token)('GET', '/concepts')).status, 401);
    }
  });

  // IP별 카운터를 쓰므로 이 파일의 마지막에 둔다 (앞 테스트의 실패 로그인도 센다)
  test('로그인 실패가 계속되면 429로 막는다', async () => {
    const email = uniqueEmail();
    let blocked = null;
    for (let i = 0; i < 12 && !blocked; i++) {
      const res = await call('POST', '/auth/login', { email, password: 'wrong-password' });
      if (res.status === 429) blocked = res;
    }
    assert.ok(blocked, '12번 안에 막혀야 한다');
    assert.ok(blocked.body.message);
  });
});
