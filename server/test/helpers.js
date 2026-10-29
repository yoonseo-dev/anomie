require('dotenv/config');
const jwt = require('jsonwebtoken');
const prisma = require('../src/prisma');
const app = require('../src/app');

// 테스트마다 서버를 임의 포트로 띄우고, 끝나면 닫는다.
async function startServer() {
  const server = await new Promise((resolve) => {
    const s = app.listen(0, () => resolve(s));
  });
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  return { baseUrl, close: () => new Promise((resolve) => server.close(resolve)) };
}

// 테스트 전용 사용자. 지우면 태그·스크랩·관계가 Cascade로 함께 지워진다.
async function createTestUser() {
  const user = await prisma.user.create({
    data: {
      email: `test-${Date.now()}-${Math.random().toString(36).slice(2)}@anomie.test`,
      password: 'x',
      nickname: '테스트',
    },
  });
  const token = jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET);
  return { user, token, remove: () => prisma.user.delete({ where: { id: user.id } }) };
}

// JSON 요청을 보내고 { status, body }를 돌려주는 함수를 만든다.
function request(baseUrl, token) {
  return async (method, path, body) => {
    const res = await fetch(`${baseUrl}${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token && { Authorization: `Bearer ${token}` }),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    return { status: res.status, body: text ? JSON.parse(text) : null };
  };
}

module.exports = { prisma, startServer, createTestUser, request };
