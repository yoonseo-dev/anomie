const { load } = require('cheerio');
const httpError = require('../utils/httpError');

const FETCH_TIMEOUT_MS = 15000;

// 기사 사이트의 응답 상태를 사용자에게 보여 줄 오류로 바꾼다.
// 주소 문제(404·410)는 400, 사이트가 막거나 사이트 쪽 문제는 502로 구분한다 (예전에는 모두 500 "서버 오류"였다).
function fetchError(status) {
  if (status === 404 || status === 410) {
    return httpError(400, '기사를 찾을 수 없습니다. 주소가 맞는지, 삭제된 기사는 아닌지 확인해주세요.');
  }
  if (status === 401 || status === 403 || status === 429) {
    return httpError(502, '이 사이트가 기사 가져오기를 막았습니다. 다른 언론사 주소로 시도해주세요.');
  }
  return httpError(502, `기사 사이트에서 페이지를 가져오지 못했습니다 (${status}). 잠시 후 다시 시도해주세요.`);
}

// URL에서 HTML을 가져와 뉴스 기사 정보를 추출
async function crawlArticle(url) {
  let res;
  try {
    res = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; AnoMieBot/1.0)' },
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
    });
  } catch (err) {
    // 주소의 서버가 없거나 응답이 없다 (DNS 실패, 연결 거부, 시간 초과)
    console.error(`[크롤링] 연결 실패 ${url}: ${err.cause?.code ?? err.name}`);
    throw httpError(502, '기사 사이트에 연결하지 못했습니다. 주소를 확인하거나 잠시 후 다시 시도해주세요.');
  }
  if (!res.ok) {
    // 어떤 주소에서 막혔는지 알아야 원인을 볼 수 있으므로 주소를 남긴다 (11-01, 주소 없이 404만 남아 원인을 못 찾음)
    console.error(`[크롤링] ${res.status} ${url}`);
    throw fetchError(res.status);
  }

  const html = await res.text();
  const $ = load(html);

  const getMeta = (property) =>
    $(`meta[property="${property}"]`).attr('content') ||
    $(`meta[name="${property}"]`).attr('content') ||
    '';

  const title =
    getMeta('og:title') ||
    $('title').text().trim() ||
    $('h1').first().text().trim() ||
    '';

  const thumbnailUrl = getMeta('og:image') || null;
  const summary = getMeta('og:description') || '';
  const publisher = getMeta('og:site_name') || null;

  // 한국 주요 뉴스 사이트 포함 다양한 본문 셀렉터를 순서대로 시도
  const contentSelectors = [
    'article',
    '[itemprop="articleBody"]',
    '#articleBody',
    '#article-body',
    '#article_content',
    '#articleContent',
    '#content-body',
    '.article_view',
    '.article-view',
    '.article_body',
    '.article-body',
    '.news_body',
    '.news-body',
    '.entry-content',
    '.post-content',
    '.story-body',
  ];

  let content = '';
  for (const selector of contentSelectors) {
    const $el = $(selector);
    if ($el.length) {
      const candidate = $el
        .find('p')
        .map((_, el) => $(el).text().trim())
        .get()
        .filter((t) => t.length > 0)
        .join('\n');
      if (candidate.length > 100) {
        content = candidate;
        break;
      }
    }
  }

  // p 태그 추출이 짧으면 컨테이너 전체 텍스트에서 보완
  if (content.length < 300) {
    for (const selector of contentSelectors) {
      const $el = $(selector);
      if ($el.length) {
        $el.find('script, style, nav, header, footer, aside, figure').remove();
        const candidate = $el.text().replace(/\s+/g, ' ').trim();
        if (candidate.length > content.length) {
          content = candidate;
          break;
        }
      }
    }
  }

  // 모든 셀렉터 실패 시 전체 p 태그에서 길이 50 이상인 것만 수집
  if (!content) {
    content = $('p')
      .map((_, el) => $(el).text().trim())
      .get()
      .filter((t) => t.length > 50)
      .join('\n');
  }

  const publishedAtStr =
    getMeta('article:published_time') ||
    $('time[datetime]').first().attr('datetime') ||
    '';
  const parsedDate = publishedAtStr ? new Date(publishedAtStr) : null;
  // 발행일을 찾지 못하면 비운다 (저장 시각으로 채우지 않는다)
  const publishedAt = parsedDate && !isNaN(parsedDate.getTime()) ? parsedDate : null;

  return { title, publisher, thumbnailUrl, summary, content, publishedAt };
}

module.exports = { crawlArticle };
