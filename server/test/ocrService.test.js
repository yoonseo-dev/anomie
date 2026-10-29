const { test, describe, afterEach, mock } = require('node:test');
const assert = require('node:assert/strict');
const { extractText, toPlainText } = require('../src/services/ocrService');
const imageInfo = require('../src/utils/imageInfo');
const { fakePng, fakeJpeg, fakeWebp } = require('./images');

// Vision 블록 하나. words: [['우리의', 'SPACE'], ['자', 'LINE_BREAK'], ...] (단어, 단어 뒤 끊김)
function block(words, yTop, yBottom) {
  return {
    boundingBox: { vertices: [{ x: 0, y: yTop }, { x: 100, y: yTop }, { x: 100, y: yBottom }, { x: 0, y: yBottom }] },
    paragraphs: [
      {
        words: words.map(([word, brk]) => ({
          symbols: [...word].map((ch, i, all) => ({
            text: ch,
            ...(i === all.length - 1 && brk && { property: { detectedBreak: { type: brk } } }),
          })),
        })),
      },
    ],
  };
}

const page = (blocks) => ({ pages: [{ width: 1000, height: 1000, blocks }] });

describe('ocrService.toPlainText', () => {
  test('끊김 정보대로 공백·줄바꿈을 넣고 블록을 줄로 잇는다', () => {
    const text = toPlainText(
      page([
        block([['우리의', 'SPACE'], ['자', 'LINE_BREAK'], ['질을', 'SPACE'], ['인정받는다.', 'LINE_BREAK']], 200, 260),
        block([['다음', 'SPACE'], ['문단', 'LINE_BREAK']], 300, 330),
      ])
    );
    assert.equal(text, '우리의 자\n질을 인정받는다.\n다음 문단');
  });

  test('페이지 맨 위·아래의 숫자만 있는 블록은 쪽번호로 보고 뺀다', () => {
    const text = toPlainText(
      page([
        block([['4']], 10, 30),
        block([['본문', 'SPACE'], ['1990년', 'SPACE'], ['이후']], 400, 430),
        block([['30']], 500, 520), // 가운데 있는 숫자는 본문일 수 있어 남긴다
        block([['-', 'SPACE'], ['31', 'SPACE'], ['-']], 950, 980),
      ])
    );
    assert.equal(text, '본문 1990년 이후\n30');
  });

  test('인식 결과가 없으면 빈 문자열', () => {
    assert.equal(toPlainText(undefined), '');
  });
});

describe('ocrService.extractText', () => {
  afterEach(() => mock.restoreAll());

  const visionReply = (status, body) =>
    mock.method(globalThis, 'fetch', async () => new Response(JSON.stringify(body), { status }));

  test('DOCUMENT_TEXT_DETECTION에 한국어 힌트를 붙여 요청하고 텍스트를 돌려준다', async () => {
    const fetch = visionReply(200, { responses: [{ fullTextAnnotation: page([block([['본문']], 400, 430)]) }] });

    const text = await extractText(Buffer.from('image'));

    assert.equal(text, '본문');
    const [url, init] = fetch.mock.calls[0].arguments;
    assert.match(url, /images:annotate$/);
    const request = JSON.parse(init.body).requests[0];
    assert.equal(request.features[0].type, 'DOCUMENT_TEXT_DETECTION');
    assert.deepEqual(request.imageContext.languageHints, ['ko']);
    assert.equal(request.image.content, Buffer.from('image').toString('base64'));
  });

  test('글자가 없으면 422, 이미지 오류는 400, 한도 초과는 503, 그 밖의 오류는 502', async () => {
    visionReply(200, { responses: [{}] });
    await assert.rejects(extractText(Buffer.from('x')), { status: 422 });

    mock.restoreAll();
    visionReply(200, { responses: [{ error: { message: 'Bad image data' } }] });
    await assert.rejects(extractText(Buffer.from('x')), { status: 400 });

    mock.restoreAll();
    visionReply(429, { error: { message: 'quota' } });
    await assert.rejects(extractText(Buffer.from('x')), { status: 503 });

    mock.restoreAll();
    visionReply(403, { error: { message: 'billing' } });
    await assert.rejects(extractText(Buffer.from('x')), { status: 502 });
  });
});

describe('imageInfo', () => {
  test('PNG·JPEG의 형식과 크기를 읽는다', () => {
    assert.deepEqual(imageInfo(fakePng(960, 1280)), { type: 'png', width: 960, height: 1280 });
    assert.deepEqual(imageInfo(fakeJpeg(3024, 4032)), { type: 'jpeg', width: 3024, height: 4032 });
  });

  test('WebP 세 가지 형식(VP8·VP8L·VP8X)의 크기를 읽는다 (확장자가 .jpg인 WebP 샘플, 10-29)', () => {
    for (const variant of ['VP8 ', 'VP8L', 'VP8X']) {
      assert.deepEqual(imageInfo(fakeWebp(960, 1280, variant)), { type: 'webp', width: 960, height: 1280 }, variant);
    }
  });

  test('그 밖의 파일은 null', () => {
    assert.equal(imageInfo(Buffer.from('GIF89a 이건 GIF 파일이다 GIF89a')), null);
    assert.equal(imageInfo(Buffer.alloc(4)), null);
    assert.equal(imageInfo('not a buffer'), null);
  });
});
