import 'package:client/app.dart';
import 'package:client/features/map/map_screen.dart';
import 'package:client/features/scrap/new_scrap_screen.dart';
import 'package:client/shared/models/scrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: AnomieApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('가짜 데이터로 그래프 요약과 최근 스크랩을 보여 준다', (tester) async {
    await pumpApp(tester);

    expect(find.text('16개 개념, 12개 연결'), findsOneWidget);
    expect(find.text('새 제안 3'), findsOneWidget);
    expect(find.text('청년 고용률 4년 만에 하락 전환'), findsOneWidget);
    expect(find.text('아노미 외 1'), findsOneWidget);
  });

  testWidgets('책 카드를 누르면 책 탭이 선택된 새 스크랩 화면이 열린다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.bySemanticsLabel('책 스크랩 추가'));
    await tester.pumpAndSettle();

    final screen = tester.widget<NewScrapScreen>(find.byType(NewScrapScreen));
    expect(screen.initialSource, ScrapSource.book);
  });

  testWidgets('그래프 카드를 누르면 마인드맵 탭으로 간다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('내 개념'));
    await tester.pumpAndSettle();

    expect(find.byType(MapScreen), findsOneWidget);
  });
}
