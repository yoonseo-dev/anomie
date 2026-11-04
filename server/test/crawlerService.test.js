const { test, describe, afterEach, mock } = require('node:test');
const assert = require('node:assert/strict');
const { crawlArticle } = require('../src/services/crawlerService');

describe('crawlerService.crawlArticle: 기사 사이트 오류', () => {
  afterEach(() => mock.restoreAll());

  const siteReply = (status, body = '') =>
    mock.method(globalThis, 'fetch', async () => new Response(body, { status }));

  // 11-01: 404를 상태 코드 없는 Error로 던져 앱에 500 "서버 오류"만 보였다
  test('없는 기사(404·410)는 400과 주소 확인 안내', async () => {
    for (const status of [404, 410]) {
      siteReply(status);
      await assert.rejects(crawlArticle('https://news.example.com/gone'), {
        status: 400,
        message: /기사를 찾을 수 없습니다/,
      });
      mock.restoreAll();
    }
  });

  test('사이트가 막으면(401·403·429) 502와 다른 언론사 안내, 그 밖의 오류는 502', async () => {
    for (const status of [401, 403, 429]) {
      siteReply(status);
      await assert.rejects(crawlArticle('https://news.example.com/a'), { status: 502, message: /막았습니다/ });
      mock.restoreAll();
    }
    siteReply(503);
    await assert.rejects(crawlArticle('https://news.example.com/a'), { status: 502, message: /\(503\)/ });
  });

  test('연결 자체가 안 되면(DNS·시간 초과) 502', async () => {
    mock.method(globalThis, 'fetch', async () => {
      throw new TypeError('fetch failed', { cause: { code: 'ENOTFOUND' } });
    });
    await assert.rejects(crawlArticle('https://no-such-host.example/a'), { status: 502, message: /연결하지 못했습니다/ });
  });

  test('정상 응답은 제목·본문을 꺼내고, 요청에 시간 제한을 건다', async () => {
    const fetch = siteReply(
      200,
      `<html><head><meta property="og:title" content="제목"></head>
       <body><article><p>${'본문 '.repeat(40)}</p></article></body></html>`,
    );

    const result = await crawlArticle('https://news.example.com/ok');

    assert.equal(result.title, '제목');
    assert.match(result.content, /^본문/);
    assert.ok(fetch.mock.calls[0].arguments[1].signal instanceof AbortSignal);
  });
});
