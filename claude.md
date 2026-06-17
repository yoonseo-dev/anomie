# Anomie 프로젝트 개요

뉴스 URL을 입력하면 Claude AI가 기사를 분석해 사회학 개념 태그를 자동으로 붙여주는 모바일 스크랩북 앱.
예를 들어 "아노미", "사회적 자본", "낙인 효과" 같은 개념이 태그로 연결된다.

## 기술 스택

- **백엔드**: Node.js + Express + Prisma ORM + PostgreSQL (Docker)
- **AI 분석**: Claude API (기사 내용 → 사회학 태그 생성)
- **크롤링**: Cheerio (정적 페이지) / Puppeteer (동적 페이지)
- **인증**: JWT
- **프론트**: Flutter / Riverpod / dio / go_router

## 폴더 구조

- `server/`: 백엔드 전체
- `client/`: Flutter 앱 전체

## 데이터 모델 핵심 관계

- User가 Article을 스크랩한다 (1:N)
- Article과 Tag는 ArticleTag를 통해 연결된다 (N:M)
- ArticleTag에는 AI가 해당 태그를 붙인 이유(reason)가 저장된다