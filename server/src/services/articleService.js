const prisma = require('../prisma');

// 기사, 태그, ArticleTag를 DB에 저장하고 태그 포함 기사를 반환
async function saveArticle({ url, userId, crawled, tags, commentary, framing, rhetoric, stakeholders, values }) {
  const article = await prisma.article.create({
    data: {
      url,
      userId,
      title: crawled.title,
      summary: crawled.summary,
      thumbnailUrl: crawled.thumbnailUrl,
      content: crawled.content,
      publishedAt: crawled.publishedAt,
      commentary: commentary ?? null,
      framing: framing ?? null,
      rhetoric: rhetoric ?? null,
      stakeholders: stakeholders ?? null,
      values: values ?? null,
    },
  });

  for (const tagData of tags) {
    // 태그는 사용자별로 소유하고, 이름은 사용자 안에서 유일하다. 이미 있으면 그대로 쓴다.
    // TODO: 기존 태그 ID 재사용 방식(doc/plan.md 7장)으로 바꾸면 이름 일치 재사용은 제거한다.
    const tag = await prisma.tag.upsert({
      where: { userId_name: { userId, name: tagData.name } },
      update: {},
      create: {
        userId,
        name: tagData.name,
        category: tagData.category ?? null,
        description: tagData.description ?? null,
      },
    });

    await prisma.articleTag.create({
      data: {
        articleId: article.id,
        tagId: tag.id,
        reason: tagData.reason,
        explanation: tagData.explanation ?? '',
      },
    });
  }

  return prisma.article.findUnique({
    where: { id: article.id },
    include: {
      articleTags: {
        include: { tag: true },
      },
    },
  });
}

module.exports = { saveArticle };
