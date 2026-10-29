const { test, describe, before, after, afterEach, mock } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { prisma, startServer, createTestUser } = require('./helpers');
const conceptService = require('../src/services/conceptService');
const { analyzeLimiter } = require('../src/middleware/rateLimit');

describe('보안 설정', () => {
  let server;
  let me;

  const raw = (path, init = {}) =>
    fetch(`${server.baseUrl}${path}`, {
      ...init,
      headers: { Authorization: `Bearer ${me.token}`, ...init.headers },
    });

  before(async () => {
    server = await startServer();
    me = await createTestUser();
  });

  afterEach(() => mock.restoreAll());

  after(async () => {
    await me.remove();
    await server.close();
    await prisma.$disconnect();
  });

  test('서버 내부 오류(500)는 메시지를 숨긴다', async () => {
    mock.method(conceptService, 'listConcepts', async () => {
      throw new Error('relation "Tag" does not exist (DB 내부 정보)');
    });
    const errors = mock.method(console, 'error', () => {});

    const res = await raw('/concepts');
    const body = await res.json();

    assert.equal(res.status, 500);
    assert.equal(body.message, '서버 오류가 발생했습니다.');
    assert.equal(errors.mock.callCount(), 1); // 로그에는 남긴다
  });

  test('서비스가 일부러 만든 502·503 안내는 그대로 보여 준다', async () => {
    mock.method(conceptService, 'listConcepts', async () => {
      throw Object.assign(new Error('잠시 후 다시 시도해주세요.'), { status: 503 });
    });
    mock.method(console, 'error', () => {});

    const res = await raw('/concepts');

    assert.equal(res.status, 503);
    assert.equal((await res.json()).message, '잠시 후 다시 시도해주세요.');
  });

  test('깨진 JSON은 400, 100kb가 넘는 본문은 413', async () => {
    const headers = { 'Content-Type': 'application/json' };

    const broken = await raw('/relations/x', { method: 'PATCH', headers, body: '{ "status": ' });
    const huge = await raw('/relations/x', {
      method: 'PATCH',
      headers,
      body: JSON.stringify({ reason: 'x'.repeat(110 * 1024) }),
    });

    assert.equal(broken.status, 400);
    assert.equal((await broken.json()).message, '요청 본문이 올바른 JSON이 아닙니다.');
    assert.equal(huge.status, 413);
  });

  test('보안 헤더를 붙이고 X-Powered-By는 뺀다', async () => {
    const res = await raw('/concepts');

    assert.equal(res.headers.get('x-powered-by'), null);
    assert.equal(res.headers.get('x-content-type-options'), 'nosniff');
  });

  test('CORS_ORIGINS가 없으면 다른 출처를 허용하지 않는다', async () => {
    const res = await raw('/concepts', { headers: { Origin: 'https://evil.example.com' } });
    assert.equal(res.headers.get('access-control-allow-origin'), null);
  });

  test('분석 라우트에 호출 제한이 걸려 있다 (응답에 RateLimit 헤더)', async () => {
    // url이 없어서 400이 나지만 제한기는 그 전에 지나간다 (실패 응답은 세지 않는다)
    const res = await raw('/articles/analyze', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });

    assert.equal(res.status, 400);
    assert.match(res.headers.get('ratelimit-policy') ?? '', /q=20/);
  });
});

describe('analyzeLimiter: 사용자별 시간·하루 상한', () => {
  // 제한기만 단 작은 앱. x-user 헤더로 사용자를 흉내 내고, x-fail이면 400으로 응답한다
  async function limitedApp(options) {
    const app = express();
    app.use((req, res, next) => {
      req.user = { userId: req.get('x-user') };
      next();
    });
    app.post('/analyze', ...analyzeLimiter(options), (req, res) => {
      res.status(req.get('x-fail') ? 400 : 200).json({ ok: true });
    });
    const server = await new Promise((resolve) => {
      const s = app.listen(0, () => resolve(s));
    });
    const hit = (user, fail = false) =>
      fetch(`http://127.0.0.1:${server.address().port}/analyze`, {
        method: 'POST',
        headers: { 'x-user': user, ...(fail && { 'x-fail': '1' }) },
      }).then(async (r) => ({ status: r.status, body: await r.json() }));
    return { hit, close: () => new Promise((r) => server.close(r)) };
  }

  test('시간당 상한을 넘으면 429와 안내 문구, 다른 사용자는 따로 센다', async () => {
    const { hit, close } = await limitedApp({ perHour: 2, perDay: 10 });
    try {
      assert.equal((await hit('a')).status, 200);
      assert.equal((await hit('a')).status, 200);
      const blocked = await hit('a');
      assert.equal(blocked.status, 429);
      assert.match(blocked.body.message, /1시간에 2회, 하루 10회/);
      assert.equal((await hit('b')).status, 200);
    } finally {
      await close();
    }
  });

  test('하루 상한이 더 작으면 그것으로 막고, 실패 응답(400)은 세지 않는다', async () => {
    const { hit, close } = await limitedApp({ perHour: 10, perDay: 2 });
    try {
      for (let i = 0; i < 5; i++) assert.equal((await hit('a', true)).status, 400);
      assert.equal((await hit('a')).status, 200);
      assert.equal((await hit('a')).status, 200);
      assert.equal((await hit('a')).status, 429);
    } finally {
      await close();
    }
  });
});
