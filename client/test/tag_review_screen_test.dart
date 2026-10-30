import 'package:client/app.dart';
import 'package:client/features/scrap/new_scrap_screen.dart';
import 'package:client/features/scrap/tag_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'helpers/fake_data.dart';
import 'helpers/signed_in.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const savedTitle = '청년 고용률 4년 만에 하락 전환, 첫 일자리까지 평균 11개월';

  /// 홈 → 기사 → 붙여넣기 → 분석하기 → 태그 확인.
  Future<void> openReview(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [...signedIn(), ...fakeData()],
        child: const AnomieApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('기사 스크랩 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('붙여넣기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('분석하기'));
    await tester.pumpAndSettle();
    expect(find.byType(TagReviewScreen), findsOneWidget);
  }

  testWidgets('찾은 개념 3개와 새 태그 표시를 보여 준다', (tester) async {
    await openReview(tester);

    expect(find.text(savedTitle), findsOneWidget);
    expect(find.text('내 태그'), findsNWidgets(2));
    expect(find.text('새 태그'), findsOneWidget);
    expect(find.text('태그 3개 저장'), findsOneWidget);
  });

  testWidgets('비슷한 내 태그를 고르면 새 태그가 내 태그로 바뀐다', (tester) async {
    await openReview(tester);

    await tester.tap(find.text('위험사회'));
    await tester.pumpAndSettle();
    expect(find.text('새 태그'), findsNothing);
    expect(find.text('내 태그'), findsNWidgets(3));
  });

  testWidgets('이름 수정하기 시트에서 이름을 바꾼다', (tester) async {
    await openReview(tester);

    await tester.tap(find.text('이름 수정하기').first);
    await tester.pumpAndSettle();
    expect(find.text('태그 이름 수정하기'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '청년 박탈감');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('청년 박탈감'), findsOneWidget);
    expect(find.text('상대적 박탈감'), findsNothing);
  });

  testWidgets('빼기는 되돌릴 수 있고, 개수가 버튼에 반영된다', (tester) async {
    await openReview(tester);

    await tester.tap(find.text('빼기').first);
    await tester.pumpAndSettle();
    expect(find.text('태그 2개 저장'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('태그 3개 저장'), findsOneWidget);
  });

  testWidgets('‹를 누르면 입력한 주소가 남은 새 스크랩 화면으로 돌아간다', (tester) async {
    await openReview(tester);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();

    expect(find.byType(NewScrapScreen), findsOneWidget);
    expect(find.text('https://hani.co.kr/arti/society/1162'), findsOneWidget);
  });

  testWidgets('저장하면 홈으로 가고 최근 스크랩 맨 위에 추가된다', (tester) async {
    await openReview(tester);

    await tester.tap(find.text('태그 3개 저장'));
    await tester.pumpAndSettle();

    expect(find.byType(TagReviewScreen), findsNothing);
    expect(find.byType(NewScrapScreen), findsNothing);
    expect(find.text('스크랩을 저장했어요'), findsOneWidget);
    expect(find.text(savedTitle), findsOneWidget);
    expect(find.text('상대적 박탈감 외 2'), findsOneWidget);
  });

  testWidgets('기사에는 근거 문장이 없다', (tester) async {
    await openReview(tester);
    expect(find.text('근거 문장'), findsNothing);
    expect(find.text('근거 문장 수정하기'), findsNothing);
  });

  group('책', () {
    /// 홈 → 책 → 페이지 촬영 → 제목 → 분석하기 → 태그 확인.
    Future<void> openBookReview(WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [...signedIn(), ...fakeData()],
          child: const AnomieApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('책 스크랩 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('페이지 촬영'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '예: 자살론'),
        '자살론',
      );
      await tester.pump();
      await tester.tap(find.text('분석하기'));
      await tester.pumpAndSettle();
      expect(find.byType(TagReviewScreen), findsOneWidget);
    }

    testWidgets('근거 문장을 보여 주고, 찾지 못한 문장에는 확인 필요를 붙인다', (tester) async {
      await openBookReview(tester);

      expect(find.text('“규범이 힘을 잃으면 욕망은 더 이상 한계를 알지 못한다.”'), findsOneWidget);
      expect(find.text('“사회가 개인을 붙잡는 힘이 약해질수록”'), findsOneWidget);
      expect(find.text('확인 필요'), findsOneWidget);
      expect(find.text('근거 문장 수정하기'), findsNWidgets(2));
    });

    testWidgets('근거 문장을 고치면 확인 필요가 사라진다', (tester) async {
      await openBookReview(tester);

      await tester.tap(find.text('근거 문장 수정하기').last);
      await tester.pumpAndSettle();
      expect(find.text('근거 문장 수정하기'), findsNWidgets(3)); // 시트 제목 포함

      await tester.enterText(
        find.byType(TextField),
        '사회가 개인을 붙잡는 힘이 약해질수록 자살은 늘어난다',
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(find.text('“사회가 개인을 붙잡는 힘이 약해질수록 자살은 늘어난다”'), findsOneWidget);
      expect(find.text('확인 필요'), findsNothing);
    });
  });
}
