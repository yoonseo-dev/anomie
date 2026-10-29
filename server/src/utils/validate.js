const { CATEGORIES } = require('../services/claudeService');

const MAX_TAGS = 10;
const MAX_EXCERPT_LENGTH = 300; // 근거 문장 1~3문장 상한

// 문자열 필드 하나를 검사한다. 비어 있으면 optional일 때 null, 아니면 에러.
function readString(body, key, { max, min = 1, optional = false }, errors) {
  const value = body[key];
  if (value === undefined || value === null || value === '') {
    if (!optional) errors.push(`${key}은(는) 필수입니다.`);
    return null;
  }
  if (typeof value !== 'string') {
    errors.push(`${key}은(는) 문자열이어야 합니다.`);
    return null;
  }
  if (value.length < min || value.length > max) {
    errors.push(`${key}은(는) ${min}~${max}자여야 합니다.`);
  }
  return value;
}

// 정수 필드. multipart로 오면 문자열이므로 숫자 문자열도 받는다.
function readInt(body, key, { min, max, optional = false }, errors) {
  const value = body[key];
  if (value === undefined || value === null || value === '') {
    if (!optional) errors.push(`${key}은(는) 필수입니다.`);
    return null;
  }
  const n = typeof value === 'string' && /^\d+$/.test(value) ? Number(value) : value;
  if (!Number.isInteger(n) || n < min || n > max) {
    errors.push(`${key}은(는) ${min}~${max} 사이의 정수여야 합니다.`);
    return null;
  }
  return n;
}

function isHttpUrl(value) {
  try {
    const { protocol } = new URL(value);
    return protocol === 'http:' || protocol === 'https:';
  } catch {
    return false;
  }
}

function readUrl(body, errors) {
  const url = readString(body, 'url', { max: 2048 }, errors);
  if (url && !isHttpUrl(url)) errors.push('url은 http 또는 https 주소여야 합니다.');
  return url;
}

// 저장 요청의 tags[]를 검사한다.
// 기존 태그는 { tagId, reason, explanation }, 새 태그는 { name, category, description, reason, explanation }.
// withExcerpt면 책 스크랩용으로 근거 문장(excerpt)을 필수로 받는다.
function readTags(body, errors, { withExcerpt = false } = {}) {
  const tags = [];
  if (!Array.isArray(body.tags) || body.tags.length < 1 || body.tags.length > MAX_TAGS) {
    errors.push(`tags는 1~${MAX_TAGS}개의 배열이어야 합니다.`);
    return tags;
  }

  body.tags.forEach((raw, i) => {
    const tagErrors = [];
    const t = raw && typeof raw === 'object' ? raw : {};
    const tag = {
      reason: readString(t, 'reason', { max: 500 }, tagErrors),
      explanation: readString(t, 'explanation', { max: 2000, optional: true }, tagErrors) ?? '',
    };
    if (withExcerpt) {
      tag.excerpt = readString(t, 'excerpt', { max: MAX_EXCERPT_LENGTH }, tagErrors);
    }
    if (t.tagId) {
      // 기존 태그: 이름·설명은 이미 DB에 있으므로 받지 않는다
      tag.tagId = readString(t, 'tagId', { max: 36 }, tagErrors);
    } else {
      tag.name = readString(t, 'name', { max: 50 }, tagErrors);
      const category = readString(t, 'category', { max: 50, optional: true }, tagErrors);
      // 고정 분야 목록 밖의 값은 "기타"로 저장한다
      tag.category = category && !CATEGORIES.includes(category) ? '기타' : category;
      tag.description = readString(t, 'description', { max: 3000, optional: true }, tagErrors);
    }
    errors.push(...tagErrors.map((e) => `tags[${i}].${e}`));
    tags.push(tag);
  });
  return tags;
}

module.exports = { readString, readInt, readUrl, readTags, MAX_EXCERPT_LENGTH };
