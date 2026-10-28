# Anomie ERD

10-28 기획 기준 8개 테이블. 실제 정의는 `server/prisma/schema.prisma`, 설계 배경은 `doc/plan.md` 3장.

```mermaid
erDiagram
  USER ||--o{ TAG : "소유"
  USER ||--o{ ARTICLE : "스크랩"
  USER ||--o{ BOOK_SCRAP : "스크랩"
  ARTICLE ||--o{ ARTICLE_TAG : ""
  TAG ||--o{ ARTICLE_TAG : ""
  BOOK_SCRAP ||--o{ BOOK_SCRAP_TAG : ""
  TAG ||--o{ BOOK_SCRAP_TAG : ""
  TAG ||--o{ CONCEPT_RELATION : "tagA"
  TAG ||--o{ CONCEPT_RELATION : "tagB"
  CONCEPT_RELATION ||--o{ CONCEPT_RELATION_EVIDENCE : "근거"
  ARTICLE |o--o{ CONCEPT_RELATION_EVIDENCE : "기사 근거"
  BOOK_SCRAP |o--o{ CONCEPT_RELATION_EVIDENCE : "책 근거"
  USER {
    uuid id PK
    string email UK
    string password "bcrypt 해시"
    string nickname
    datetime createdAt
    datetime updatedAt
  }
  TAG {
    uuid id PK
    uuid userId FK "userId+name 유일"
    string name
    string category "nullable, 통계용"
    text description "nullable"
    boolean descriptionByAi "사용자가 고치면 false"
    datetime createdAt
    datetime updatedAt
  }
  ARTICLE {
    uuid id PK
    uuid userId FK "userId+url 유일"
    string url
    string title
    string publisher "nullable"
    string thumbnailUrl "nullable"
    datetime publishedAt "nullable"
    text content "본문, 5000자 상한"
    text summary "관계 제안 입력"
    text commentary "nullable"
    text framing "nullable"
    text rhetoric "nullable"
    text stakeholders "nullable"
    text values "nullable"
    datetime createdAt
  }
  BOOK_SCRAP {
    uuid id PK
    uuid userId FK
    string bookTitle
    string author "nullable"
    int page "nullable, 직접 입력"
    text summary "관계 제안 입력"
    datetime createdAt
  }
  ARTICLE_TAG {
    uuid id PK
    uuid articleId FK "articleId+tagId 유일"
    uuid tagId FK
    text reason "태그를 붙인 근거"
    text explanation "이 기사에서의 풀이"
  }
  BOOK_SCRAP_TAG {
    uuid id PK
    uuid bookScrapId FK "bookScrapId+tagId 유일"
    uuid tagId FK
    text reason
    text explanation
    text excerpt "근거 문장, OCR 원문과 일치"
  }
  CONCEPT_RELATION {
    uuid id PK
    uuid tagAId FK "tagAId < tagBId (무방향)"
    uuid tagBId FK "tagAId+tagBId 유일"
    text reason "관계 설명"
    enum status "SUGGESTED / APPROVED / REJECTED"
    datetime createdAt
    datetime updatedAt
  }
  CONCEPT_RELATION_EVIDENCE {
    uuid id PK
    uuid relationId FK
    uuid articleId FK "nullable"
    uuid bookScrapId FK "nullable, 둘 중 정확히 하나"
  }
```

## 스키마로 표현하지 못한 규칙

- **관계는 무방향**: `CONCEPT_RELATION`은 항상 `tagAId < tagBId`로 저장한다 (DB CHECK 제약). A—B / B—A 중복과 자기 자신과의 관계를 막는다.
- **근거는 하나만**: `CONCEPT_RELATION_EVIDENCE`는 `articleId` / `bookScrapId` 중 정확히 하나만 채운다 (DB CHECK 제약).
- **근거가 사라진 관계**: 스크랩을 지우면 근거 행은 자동으로 지워진다(Cascade). 근거가 0개가 된 관계는 서버가 같은 트랜잭션에서 지우되, `REJECTED` 관계는 같은 쌍 재제안을 막기 위해 남긴다.
- **보관하지 않는 것**: 책 사진과 OCR 추출 전문은 저장하지 않고, 근거 문장(`excerpt`)만 저장한다.
