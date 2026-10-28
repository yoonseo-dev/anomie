const prisma = require('../src/prisma');

async function main() {
  const at = await prisma.articleTag.deleteMany();
  const a = await prisma.article.deleteMany();
  const t = await prisma.tag.deleteMany();
  const u = await prisma.user.deleteMany();
  console.log('ArticleTag 삭제:', at.count, '건');
  console.log('Article 삭제:', a.count, '건');
  console.log('Tag 삭제:', t.count, '건');
  await prisma.$disconnect();
}

main().catch((e) => { console.error(e); process.exit(1); });
