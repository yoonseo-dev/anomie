import 'package:client/app.dart';
import 'package:client/features/scrap/new_scrap_screen.dart';
import 'package:client/features/scrap/scrap_validators.dart';
import 'package:client/features/scrap/tag_review_screen.dart';
import 'package:client/shared/data/scrap_analysis_repository.dart';
import 'package:client/shared/models/scrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late ProviderContainer container;

  /// 홈에서 기사/책 카드를 눌러 새 스크랩 화면을 연다.
  Future<void> openNewScrap(WidgetTester tester, ScrapSource source) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        scrapAnalysisRepositoryProvider.overrideWithValue(
          const FakeScrapAnalysisRepository(delay: Duration(milliseconds: 50)),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AnomieApp()),
    );
    await tester.pumpAndSettle();
    final label = source == ScrapSource.article ? '기사 스크랩 추가' : '책 스크랩 추가';
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pumpAndSettle();
    expect(find.byType(NewScrapScreen), findsOneWidget);
  }

  FilledButton analyzeButton(WidgetTester tester) => tester.widget(
    find.ancestor(of: find.text('분석하기'), matching: find.byType(FilledButton)),
  );

  testWidgets('기사: 처음엔 분석하기가 꺼져 있고, 붙여넣기 하면 켜진다', (tester) async {
    await openNewScrap(tester, ScrapSource.article);

    expect(analyzeButton(tester).onPressed, isNull);
    expect(find.text('hani.co.kr/arti/society/1162'), findsOneWidget);

    await tester.tap(find.text('붙여넣기'));
    await tester.pumpAndSettle();

    expect(analyzeButton(tester).onPressed, isNotNull);
    // 이미 넣은 주소이므로 클립보드 카드는 사라진다.
    expect(find.text('복사해 둔 주소'), findsNothing);
  });

  testWidgets('기사: 잘못된 주소는 입력을 마치면 오류를 보여 준다', (tester) async {
    await openNewScrap(tester, ScrapSource.article);

    await tester.enterText(find.byType(TextField), 'hani.co.kr');
    await tester.pump();
    expect(find.text(ScrapValidators.articleUrlMessage), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text(ScrapValidators.articleUrlMessage), findsOneWidget);
    expect(analyzeButton(tester).onPressed, isNull);
  });

  testWidgets('기사: 분석하면 결과를 담고 태그 확인 화면으로 바뀐다', (tester) async {
    await openNewScrap(tester, ScrapSource.article);

    await tester.tap(find.text('붙여넣기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('분석하기'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(TagReviewScreen), findsOneWidget);
    expect(find.byType(NewScrapScreen), findsNothing);
    expect(container.read(latestAnalysisProvider)?.tags, hasLength(3));
  });

  testWidgets('책: 촬영하고 제목을 넣어야 분석하기가 켜진다', (tester) async {
    await openNewScrap(tester, ScrapSource.book);

    expect(find.text('페이지 촬영'), findsOneWidget);
    expect(analyzeButton(tester).onPressed, isNull);

    await tester.tap(find.text('페이지 촬영'));
    await tester.pumpAndSettle();
    expect(find.text('다시 찍기'), findsOneWidget);
    expect(analyzeButton(tester).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextFormField, '예: 자살론'), '자살론');
    await tester.pump();
    expect(analyzeButton(tester).onPressed, isNotNull);

    await tester.enterText(find.widgetWithText(TextFormField, '쪽'), '이백');
    await tester.pump();
    expect(find.text(ScrapValidators.pageMessage), findsOneWidget);
    expect(analyzeButton(tester).onPressed, isNull);
  });

  testWidgets('토글로 바꿔도 입력한 내용이 남는다', (tester) async {
    await openNewScrap(tester, ScrapSource.article);

    await tester.tap(find.text('붙여넣기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('책'));
    await tester.pumpAndSettle();
    expect(find.text('페이지 촬영'), findsOneWidget);

    await tester.tap(find.text('기사'));
    await tester.pumpAndSettle();
    expect(find.text('https://hani.co.kr/arti/society/1162'), findsOneWidget);
  });

  testWidgets('닫기를 누르면 홈으로 돌아간다', (tester) async {
    await openNewScrap(tester, ScrapSource.article);

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(NewScrapScreen), findsNothing);
    expect(find.text('최근 스크랩'), findsOneWidget);
  });
}
