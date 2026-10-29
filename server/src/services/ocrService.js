const httpError = require('../utils/httpError');

const VISION_URL = 'https://vision.googleapis.com/v1/images:annotate';

// 페이지 위·아래 이 비율 안에 있는 숫자만의 블록은 쪽번호로 보고 지운다
const PAGE_NUMBER_MARGIN = 0.12;

// Vision이 알려 주는 글자 뒤 끊김을 공백·줄바꿈으로 바꾼다
const BREAKS = {
  SPACE: ' ',
  SURE_SPACE: ' ',
  EOL_SURE_SPACE: '\n',
  LINE_BREAK: '\n',
  HYPHEN: '\n',
};

function blockText(block) {
  let text = '';
  for (const paragraph of block.paragraphs ?? []) {
    for (const word of paragraph.words ?? []) {
      for (const symbol of word.symbols ?? []) {
        text += symbol.text + (BREAKS[symbol.property?.detectedBreak?.type] ?? '');
      }
    }
  }
  return text.trim();
}

function isPageNumber(block, text, pageHeight) {
  if (!/^[-–—\s]*\d{1,4}[-–—\s]*$/.test(text)) return false;
  const ys = (block.boundingBox?.vertices ?? []).map((v) => v.y ?? 0);
  if (!ys.length || !pageHeight) return false;
  const center = (Math.min(...ys) + Math.max(...ys)) / 2 / pageHeight;
  return center < PAGE_NUMBER_MARGIN || center > 1 - PAGE_NUMBER_MARGIN;
}

// Vision 응답(fullTextAnnotation)을 본문 텍스트로 정리한다. 블록을 순서대로 잇고 쪽번호 블록은 뺀다.
// 머리말·앱 표시 같은 나머지 잡음은 규칙으로 거르지 않고 Claude 프롬프트에서 무시하게 한다.
function toPlainText(annotation) {
  const lines = [];
  for (const page of annotation?.pages ?? []) {
    for (const block of page.blocks ?? []) {
      const text = blockText(block);
      if (text && !isPageNumber(block, text, page.height)) lines.push(text);
    }
  }
  return lines.join('\n');
}

// 사진 한 장을 Google Cloud Vision(DOCUMENT_TEXT_DETECTION)으로 읽어 텍스트를 돌려준다.
// 사진은 이 요청에만 쓰고 어디에도 저장하지 않는다.
async function extractText(imageBuffer) {
  let res;
  try {
    res = await fetch(VISION_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': process.env.GOOGLE_VISION_API_KEY,
      },
      body: JSON.stringify({
        requests: [
          {
            image: { content: imageBuffer.toString('base64') },
            features: [{ type: 'DOCUMENT_TEXT_DETECTION' }],
            imageContext: { languageHints: ['ko'] },
          },
        ],
      }),
    });
  } catch (err) {
    console.error(`[OCR] 연결 실패: ${err.message}`);
    throw httpError(502, '사진의 글자를 읽지 못했습니다. 잠시 후 다시 시도해주세요.');
  }

  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    console.error(`[OCR] Vision 오류 ${res.status}: ${body.error?.message}`);
    if (res.status === 429) throw httpError(503, '사진 분석 요청이 많습니다. 잠시 후 다시 시도해주세요.');
    throw httpError(502, '사진의 글자를 읽지 못했습니다. 잠시 후 다시 시도해주세요.');
  }

  const result = body.responses?.[0] ?? {};
  if (result.error) {
    // 이미지 자체 문제 (깨진 파일 등)
    console.error(`[OCR] 이미지 오류: ${result.error.message}`);
    throw httpError(400, '사진을 읽을 수 없습니다. 다른 사진으로 다시 시도해주세요.');
  }

  const text = toPlainText(result.fullTextAnnotation);
  console.log(`[OCR] ${text.length}자 인식`);
  if (!text) {
    throw httpError(422, '사진에서 글자를 찾지 못했습니다. 페이지가 잘 보이게 다시 찍어주세요.');
  }
  return text;
}

module.exports = { extractText, toPlainText };
