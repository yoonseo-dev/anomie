# Anomie

뉴스 기사(URL)와 책 구절(사진 → OCR)을 스크랩하면 Claude가 사회학·철학 개념 태그를 제안하고,
사용자가 승인한 개념들 사이의 관계를 지식 그래프(마인드맵)로 쌓아 가는 모바일 "개념 노트" 앱.
이론(책)과 현실(뉴스)을 개념으로 잇는 것이 핵심이다.
예: "아노미", "사회적 자본", "낙인 효과".

핵심 원칙은 **"Claude가 제안 → 사용자가 승인"**이다. 태그도, 개념 간 관계도 이 구조를 따른다.

## 저장소 구조

- `server/`: 백엔드 (Node.js + Express 5 + Prisma 7 + PostgreSQL, CommonJS)
- `client/`: Flutter 앱 (Riverpod 3, go_router)
- `doc/plan.md`: **최신 기획서이자 진행 상황** (10-28). 결정·미결 사항은 여기를 기준으로 하고,
  큰 작업을 끝내면 갱신한다.
- `doc/`: 기획·설계 문서. `doc/plan.md` 외의 문서(0930 변경사항, `plan_updated.md` 등)는 이전 버전이다.
- `docker-compose.yml` (루트): PostgreSQL 17, 호스트 포트 **5433**

## 자주 쓰는 명령

```bash
# DB
docker compose up -d                 # 루트에서

# 서버 (server/)
npm start                            # node index.js, 기본 포트 3000
npx prisma migrate dev --name <이름>  # 스키마 변경 후
npx prisma generate

# 클라이언트 (client/)
flutter analyze
flutter test --concurrency=1         # 기본 병렬 실행은 중간에 멈춘다 (원인 미해결)
flutter build web --release          # 결과물: client/build/web
```

## 도메인 용어

| 화면/코드 | DB (현재 → 목표) | 뜻 |
|---|---|---|
| 스크랩 `Scrap` | `Article` (+ 예정 `BookScrap`) | 기사 또는 책 구절 한 건 |
| 개념 `Concept` / 태그 | `Tag` | 사회학 개념. 사용자별 소유 예정 |
| 풀이 `explanation` | `ArticleTag.explanation` | 이 스크랩에서 그 개념이 어떻게 드러나는지 |
| 이유 `reason` | `ArticleTag.reason` | AI가 태그를 붙인 근거 |
| 근거 문장 `excerpt` | (예정) `BookScrapTag.excerpt` | 책에서 개념을 뽑은 1~3문장. OCR 텍스트에 글자 그대로 있어야 한다 |
| 연결/관계 `ConceptLink` | (예정) `ConceptRelation` | 개념끼리의 무방향 연결. 제안(점선) / 승인(실선) / 거절(보존, 재제안 방지) |

- 관계는 **사용자의 스크랩에 근거가 있을 때만** 제안한다 (서로 다른 스크랩에 걸친 근거 허용).
  교과서식 이론적 연결만으로는 제안하지 않는다.
- 책 사진·OCR 추출 전문은 저장하지 않는다. 근거 문장만 저장한다.

## 관계 제안을 승인하는 곳 (doc/plan.md 8-1·8-2)

- **관리 목록:** 관리 탭 → 관계 탭의 "확인 기다리는 제안"에서 승인·거절·이유 수정·연결 끊기를 한다.
  개념 상세의 "제안 확인하기"도 이 탭(`AppRoutes.manageRelations`)으로 보낸다.
- **마인드맵:** 승인 = 실선, 제안 = 점선이고, **점선을 눌러 승인·거절도 할 수 있어야 한다** (아직 미구현).
- 별도 제안함 화면이나 알림 뱃지는 만들지 않는다. 새 제안은 홈·마인드맵의 점선으로 발견하게 한다.

## 현재 상태와 주의점

- **DB는 10-28 기획 기준 8개 테이블로 재설계됐다** (`server/prisma/schema.prisma`). 테이블은
  USER, TAG(+userId, 사용자 안에서 이름 유일), ARTICLE, BOOK_SCRAP,
  ARTICLE_TAG, BOOK_SCRAP_TAG, CONCEPT_RELATION, CONCEPT_RELATION_EVIDENCE다.
  관계의 근거 스크랩이 모두 지워지면 관계도 지운다 (거절한 관계는 보존).
  관계는 항상 `tagAId < tagBId`로 저장하고, 근거 행은 기사/책 중 하나만 채운다 (마이그레이션 SQL의 CHECK 제약).
  **서버 코드는 아직 옛 흐름이다** (분석 즉시 저장, 이름 일치 태그 재사용). 책·관계 API는 없다.
- **클라이언트는 서버와 연결되지 않았다.** `client/lib/shared/data/`의 저장소는 모두
  `Fake...Repository`(메모리 가짜 데이터)다. 실제 연동은 같은 추상 클래스를 구현하는
  dio 버전을 만들어 Provider만 바꾸는 방식으로 한다. (`dio`는 아직 pubspec에 없다.)
- 서버 API는 현재 `/auth/signup`, `/auth/login`, `/articles` (GET 목록·상세, POST, DELETE)뿐이다.
- 기사 분석 모델은 `server/src/services/claudeService.js`에 지정돼 있다.
- **`server/scripts/cleanup.js`는 DB의 모든 데이터를 지운다.** 사용자가 요청할 때만 실행한다.
- 비밀값은 `server/.env`(DATABASE_URL, JWT_SECRET, ANTHROPIC_API_KEY)에 있다.
  읽거나 출력하지 않는다.

## 서버 규칙

- 라우트(`src/routes/`)는 입력 검증과 응답만 맡고, 로직은 `src/services/`에 둔다.
- 인증이 필요한 라우트에는 `middleware/auth.js`를 붙인다. `req.user = { userId, email }`.
- 에러는 `next(err)`로 넘긴다. 응답 키는 `{ message }`로 통일한다.
  (`POST /articles`에 남아 있는 `{ error }`는 정리 대상)
- Prisma 7은 내장 드라이버가 없다. 반드시 `src/prisma.js`의 싱글톤(pg 어댑터)을 쓴다.
- 다른 사용자의 데이터에 접근하지 않도록 조회 조건에 항상 `userId`를 넣는다.

## 클라이언트 규칙

- 구조: `core/`(라우터·테마), `features/<화면>/`(화면 + controller + widgets/),
  `shared/`(data·models·공용 widgets)
- 경로는 문자열을 직접 쓰지 않고 `AppRoutes` 상수를 쓴다.
  하단 탭 3개(홈·마인드맵·관리)는 StatefulShellRoute로 묶여 있다.
- **디자인:** Figma 기준이며 검정/흰색 두 색만 쓴다.
  색·간격·글꼴은 `core/theme/`의 `AppColors`·`AppSpacing`·`AppRadius`·`AppTypography`만 쓰고,
  새 값을 하드코딩하지 않는다. 회색은 검정의 투명도로 표현한다.
- 공용 위젯(`TagChip`, `PillButton`, `OutlinedCard`, `ConfirmDialog` 등)이 있으면 새로 만들지 않고 재사용한다.
  디버그 모드의 `/dev/widgets`에서 공용 위젯을 한눈에 볼 수 있다.
- 데이터를 바꾸는 동작(승인·삭제·병합 등) 뒤에는 관련 Provider를 invalidate해서
  홈·마인드맵·상세가 함께 갱신되게 한다. (`features/manage/concept_actions.dart` 참고)
- 테스트는 `ProviderScope` overrides로 `Fake...Repository(delay: Duration.zero)`를 주입한다.
  위젯 테스트에서는 `GoogleFonts.config.allowRuntimeFetching = false`를 설정한다.

## 작업 방식

- 주석, 커밋 메시지, UI 문구는 한국어로 쓴다.
- 기능을 바꾸면 테스트도 함께 추가하거나 고치고, 끝내기 전에
  `flutter analyze`와 `flutter test --concurrency=1`을 통과시킨다.
