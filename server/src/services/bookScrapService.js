const prisma = require('../prisma');
const ocrService = require('./ocrService');
const claudeService = require('./claudeService');
const evalService = require('./evalService');
const { findExistingTags, toSuggestedTags, resolveTags } = require('./tagService');
const { MAX_EXCERPT_LENGTH } = require('../utils/validate');

const BOOK_SCRAP_INCLUDE = {
  bookTags: {
    include: { tag: true },
  },
};

// 공백·줄바꿈을 모두 지운다. 한국어 책은 단어 중간에서도 줄을 바꿔서
// OCR 텍스트의 공백이 원문과 다를 수 있으므로, 근거 문장은 공백을 빼고 글자만 대조한다.
const compact = (s) => s.normalize('NFC').replace(/\s+/g, '');

const MAX_EXCERPT_PIECES = 3;

// 떨어진 구간은 말줄임표로 이어 한 문자열로 저장한다 (원문에서 이어진 문장이 아님을 드러낸다)
const joinExcerpts = (pieces) => pieces.map((p) => p.trim()).filter(Boolean).join(' … ');

// 근거 문장 구간이 모두 OCR 텍스트에 글자 그대로 있는지 확인한다. 구간 수·전체 길이 상한도 지켜야 한다.
function areExcerptsInText(pieces, ocrText) {
  const text = compact(ocrText);
  const needles = (pieces ?? []).map(compact).filter(Boolean);
  return (
    needles.length > 0 &&
    needles.length <= MAX_EXCERPT_PIECES &&
    joinExcerpts(pieces).length <= MAX_EXCERPT_LENGTH &&
    needles.every((n) => text.includes(n))
  );
}

// 책 페이지 사진을 OCR로 읽고 Claude로 분석해 태그 제안을 돌려준다. DB에는 저장하지 않는다.
// 사진과 OCR 전문은 응답 뒤 버린다. ocrText는 승인 화면에서 근거 문장과 대조하라고 돌려줄 뿐 저장하지 않는다.
// 근거 문장이 OCR 텍스트에 그대로 없는 태그도 버리지 않고 excerptVerified: false("확인 필요")로 넘긴다.
async function analyzeBookPage({ userId, image, bookTitle, author, page }) {
  const ocrText = await ocrService.extractText(image);

  const existingTags = await findExistingTags(userId);
  const analysis = await claudeService.analyzeBookPage({ ocrText, bookTitle, author }, existingTags);

  const withExcerpts = analysis.tags.map(({ excerpts, ...t }) => ({
    ...t,
    excerpt: joinExcerpts(excerpts),
    excerptVerified: areExcerptsInText(excerpts, ocrText),
  }));
  const tags = toSuggestedTags(withExcerpts, existingTags);
  const unverified = tags.filter((t) => !t.excerptVerified).length;
  if (unverified) console.log(`[근거 문장] ${tags.length}개 중 ${unverified}개 확인 필요`);

  const result = { bookTitle, author, page, summary: analysis.summary, ocrText, tags };

  // 비용·품질 기록 (응답 뒤 백그라운드에서 채점). OCR은 사진 한 장 = 1단위
  evalService.recordInBackground({
    kind: 'book',
    userId,
    input: { bookTitle, author, page },
    source: ocrText,
    existingTags,
    rawTags: analysis.tags,
    result,
    usage: analysis.usage,
    ocrUnits: 1,
  });
  return result;
}

// 사용자가 승인한 분석 결과를 책 스크랩·태그·BookScrapTag로 한 번에 저장한다.
// OCR 텍스트는 이미 버렸으므로 근거 문장은 길이만 확인한다 (사용자가 실물 책과 대조해 고쳤을 수 있다).
async function saveBookScrap({ userId, bookScrap, tags }) {
  return prisma.$transaction(async (tx) => {
    const resolved = await resolveTags(tx, userId, tags);
    return tx.bookScrap.create({
      data: {
        ...bookScrap,
        userId,
        bookTags: { create: resolved },
      },
      include: BOOK_SCRAP_INCLUDE,
    });
  });
}

module.exports = { analyzeBookPage, saveBookScrap, BOOK_SCRAP_INCLUDE };
