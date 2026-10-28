-- CreateEnum
CREATE TYPE "RelationStatus" AS ENUM ('SUGGESTED', 'APPROVED', 'REJECTED');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "nickname" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Tag" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "category" TEXT,
    "description" TEXT,
    "descriptionByAi" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Tag_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Article" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "publisher" TEXT,
    "thumbnailUrl" TEXT,
    "publishedAt" TIMESTAMP(3),
    "content" TEXT NOT NULL,
    "summary" TEXT NOT NULL,
    "commentary" TEXT,
    "framing" TEXT,
    "rhetoric" TEXT,
    "stakeholders" TEXT,
    "values" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Article_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BookScrap" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "bookTitle" TEXT NOT NULL,
    "author" TEXT,
    "page" INTEGER,
    "summary" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BookScrap_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ArticleTag" (
    "id" TEXT NOT NULL,
    "articleId" TEXT NOT NULL,
    "tagId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "explanation" TEXT NOT NULL,

    CONSTRAINT "ArticleTag_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BookScrapTag" (
    "id" TEXT NOT NULL,
    "bookScrapId" TEXT NOT NULL,
    "tagId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "explanation" TEXT NOT NULL,
    "excerpt" TEXT NOT NULL,

    CONSTRAINT "BookScrapTag_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ConceptRelation" (
    "id" TEXT NOT NULL,
    "tagAId" TEXT NOT NULL,
    "tagBId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "status" "RelationStatus" NOT NULL DEFAULT 'SUGGESTED',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ConceptRelation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ConceptRelationEvidence" (
    "id" TEXT NOT NULL,
    "relationId" TEXT NOT NULL,
    "articleId" TEXT,
    "bookScrapId" TEXT,

    CONSTRAINT "ConceptRelationEvidence_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Tag_userId_name_key" ON "Tag"("userId", "name");

-- CreateIndex
CREATE INDEX "Article_userId_createdAt_idx" ON "Article"("userId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "Article_userId_url_key" ON "Article"("userId", "url");

-- CreateIndex
CREATE INDEX "BookScrap_userId_createdAt_idx" ON "BookScrap"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "ArticleTag_tagId_idx" ON "ArticleTag"("tagId");

-- CreateIndex
CREATE UNIQUE INDEX "ArticleTag_articleId_tagId_key" ON "ArticleTag"("articleId", "tagId");

-- CreateIndex
CREATE INDEX "BookScrapTag_tagId_idx" ON "BookScrapTag"("tagId");

-- CreateIndex
CREATE UNIQUE INDEX "BookScrapTag_bookScrapId_tagId_key" ON "BookScrapTag"("bookScrapId", "tagId");

-- CreateIndex
CREATE INDEX "ConceptRelation_tagBId_idx" ON "ConceptRelation"("tagBId");

-- CreateIndex
CREATE UNIQUE INDEX "ConceptRelation_tagAId_tagBId_key" ON "ConceptRelation"("tagAId", "tagBId");

-- CreateIndex
CREATE INDEX "ConceptRelationEvidence_articleId_idx" ON "ConceptRelationEvidence"("articleId");

-- CreateIndex
CREATE INDEX "ConceptRelationEvidence_bookScrapId_idx" ON "ConceptRelationEvidence"("bookScrapId");

-- CreateIndex
CREATE UNIQUE INDEX "ConceptRelationEvidence_relationId_articleId_key" ON "ConceptRelationEvidence"("relationId", "articleId");

-- CreateIndex
CREATE UNIQUE INDEX "ConceptRelationEvidence_relationId_bookScrapId_key" ON "ConceptRelationEvidence"("relationId", "bookScrapId");

-- AddForeignKey
ALTER TABLE "Tag" ADD CONSTRAINT "Tag_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Article" ADD CONSTRAINT "Article_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookScrap" ADD CONSTRAINT "BookScrap_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ArticleTag" ADD CONSTRAINT "ArticleTag_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "Article"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ArticleTag" ADD CONSTRAINT "ArticleTag_tagId_fkey" FOREIGN KEY ("tagId") REFERENCES "Tag"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookScrapTag" ADD CONSTRAINT "BookScrapTag_bookScrapId_fkey" FOREIGN KEY ("bookScrapId") REFERENCES "BookScrap"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookScrapTag" ADD CONSTRAINT "BookScrapTag_tagId_fkey" FOREIGN KEY ("tagId") REFERENCES "Tag"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ConceptRelation" ADD CONSTRAINT "ConceptRelation_tagAId_fkey" FOREIGN KEY ("tagAId") REFERENCES "Tag"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ConceptRelation" ADD CONSTRAINT "ConceptRelation_tagBId_fkey" FOREIGN KEY ("tagBId") REFERENCES "Tag"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ConceptRelationEvidence" ADD CONSTRAINT "ConceptRelationEvidence_relationId_fkey" FOREIGN KEY ("relationId") REFERENCES "ConceptRelation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ConceptRelationEvidence" ADD CONSTRAINT "ConceptRelationEvidence_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "Article"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ConceptRelationEvidence" ADD CONSTRAINT "ConceptRelationEvidence_bookScrapId_fkey" FOREIGN KEY ("bookScrapId") REFERENCES "BookScrap"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 근거 행에는 기사 또는 책 스크랩 중 정확히 하나만 채운다 (Prisma 스키마로는 표현할 수 없음).
ALTER TABLE "ConceptRelationEvidence" ADD CONSTRAINT "ConceptRelationEvidence_exactly_one_scrap"
  CHECK (("articleId" IS NULL) <> ("bookScrapId" IS NULL));

-- 무방향 관계는 항상 tagAId < tagBId로 저장한다 (A—B / B—A 중복 및 자기 자신과의 관계 방지).
ALTER TABLE "ConceptRelation" ADD CONSTRAINT "ConceptRelation_ordered_pair"
  CHECK ("tagAId" < "tagBId");
