const { load } = require('cheerio');

// URL에서 HTML을 가져와 뉴스 기사 정보를 추출
async function crawlArticle(url) {
  const res = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; AnoMieBot/1.0)' },
  });
  if (!res.ok) throw new Error(`페이지를 가져올 수 없습니다: ${res.status}`);

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

  const thumbnailUrl = getMeta('og:image') || '';
  const summary = getMeta('og:description') || '';

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
  const publishedAt = parsedDate && !isNaN(parsedDate.getTime()) ? parsedDate : new Date();

  return { title, thumbnailUrl, summary, content, publishedAt };
}

module.exports = { crawlArticle };
