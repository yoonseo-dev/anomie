import 'package:client/app.dart';
import 'package:client/features/concept/concept_detail_screen.dart';
import 'package:client/features/manage/manage_screen.dart';
import 'package:client/features/map/map_screen.dart';
import 'package:client/shared/data/concept_graph_repository.dart';
import 'package:client/shared/data/concept_repository.dart';
import 'package:client/shared/data/scrap_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// 마인드맵 → 자세히 → 아노미 상세.
  Future<void> openAnomie(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scrapRepositoryProvider.overrideWithValue(
            FakeScrapRepository(delay: Duration.zero),
          ),
          conceptRepositoryProvider.overrideWithValue(
            FakeConceptRepository(delay: Duration.zero),
          ),
          conceptGraphRepositoryProvider.overrideWithValue(
            FakeConceptGraphRepository(delay: Duration.zero),
          ),
        ],
        child: const AnomieApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('마인드맵'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('자세히'));
    await tester.pumpAndSettle();
    expect(find.byType(ConceptDetailScreen), findsOneWidget);
  }

  Finder inDetail(Finder f) =>
      find.descendant(of: find.byType(ConceptDetailScreen).last, matching: f);

  /// 목록 캐시에 이미 만들어져 있어도 화면 안으로 실제로 끌어온다.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: inDetail(find.byType(Scrollable)).first,
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  testWidgets('제목, 개수, 설명 배지, 처음 등장을 보여 준다', (tester) async {
    await openAnomie(tester);

    expect(inDetail(find.text('스크랩 3   연결 4   제안 2')), findsOneWidget);
    expect(inDetail(find.text('AI 생성')), findsOneWidget);

    final footer = inDetail(find.text('9월 21일, 자살론에서 처음 등장'));
    await scrollTo(tester, footer);
    expect(footer, findsOneWidget);
  });

  testWidgets('수정하기로 설명을 바꾸면 직접 씀으로 표시되고, 다시 수정할 수 있다', (tester) async {
    await openAnomie(tester);

    await tester.tap(inDetail(find.text('수정하기')));
    await tester.pumpAndSettle();
    expect(find.text('개념 설명 수정하기'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '규범이 흔들리는 상태.');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(inDetail(find.text('규범이 흔들리는 상태.')), findsOneWidget);
    expect(inDetail(find.text('직접 씀')), findsOneWidget);
    expect(inDetail(find.text('수정하기')), findsOneWidget);
  });

  testWidgets('연결된 개념 칩을 누르면 그 개념의 상세가 열린다', (tester) async {
    await openAnomie(tester);

    final chip = inDetail(find.text('사회적 연대'));
    await scrollTo(tester, chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(inDetail(find.text('스크랩 0   연결 2   제안 0')), findsOneWidget);
  });

  testWidgets('제안 확인하기는 관리 탭으로 간다', (tester) async {
    await openAnomie(tester);

    final link = inDetail(find.text('제안 확인하기')).first;
    await scrollTo(tester, link);
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.byType(ConceptDetailScreen), findsNothing);
    expect(find.byType(ManageScreen), findsOneWidget);
  });

  testWidgets('마인드맵 버튼은 이 개념을 가운데에 두고 마인드맵을 연다', (tester) async {
    await openAnomie(tester);

    // 다른 개념 상세로 들어간 뒤 그 개념으로 마인드맵 열기.
    final chip = inDetail(find.text('불안정 노동'));
    await scrollTo(tester, chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(inDetail(find.widgetWithText(TextButton, '마인드맵')));
    await tester.pumpAndSettle();

    expect(find.byType(ConceptDetailScreen), findsNothing);
    expect(
      find.descendant(
        of: find.byType(MapScreen),
        matching: find.text('스크랩 2  연결 3  제안 0'),
      ),
      findsOneWidget,
    );
  });
}
