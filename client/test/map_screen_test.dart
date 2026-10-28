import 'package:client/app.dart';
import 'package:client/features/concept/concept_detail_screen.dart';
import 'package:client/features/map/map_screen.dart';
import 'package:client/shared/data/concept_graph_repository.dart';
import 'package:client/shared/models/concept_graph.dart';
import 'package:client/shared/widgets/pill_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> openMap(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: AnomieApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('마인드맵'));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
  }

  Finder summaryCardText(String text) =>
      find.descendant(of: find.byType(MapScreen), matching: find.text(text));

  testWidgets('스크랩이 가장 많은 개념을 가운데에 두고 하단 메뉴도 보인다', (tester) async {
    await openMap(tester);

    expect(summaryCardText('스크랩 3  연결 4  제안 2'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.byTooltip('이전 개념'), findsNothing);
  });

  testWidgets('개념 카드는 하단 메뉴보다 위에 있다', (tester) async {
    await openMap(tester);

    final cardBottom = tester.getBottomLeft(find.text('자세히')).dy;
    final navTop = tester.getTopLeft(find.text('홈')).dy;
    expect(cardBottom, lessThan(navTop));
  });

  testWidgets('개념을 누르면 가운데가 바뀌고, 뒤로 버튼으로 돌아온다', (tester) async {
    await openMap(tester);

    await tester.tap(find.bySemanticsLabel('불안정 노동'));
    await tester.pumpAndSettle();
    expect(summaryCardText('스크랩 2  연결 3  제안 0'), findsOneWidget);
    expect(find.byTooltip('이전 개념'), findsOneWidget);

    await tester.tap(find.byTooltip('이전 개념'));
    await tester.pumpAndSettle();
    expect(summaryCardText('스크랩 3  연결 4  제안 2'), findsOneWidget);
  });

  testWidgets('자세히를 누르면 개념 상세가 하단 메뉴 없이 열린다', (tester) async {
    await openMap(tester);

    await tester.tap(find.text('자세히'));
    await tester.pumpAndSettle();

    final detail = tester.widget<ConceptDetailScreen>(
      find.byType(ConceptDetailScreen),
    );
    expect(detail.conceptId, 'anomie');
    expect(find.byType(PillBottomNav), findsNothing);
  });

  testWidgets('1단계가 상한을 넘으면 "+N"을 눌러 숨은 개념으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final hub = ConceptGraph(
      nodes: [
        const ConceptNode(id: 'hub', name: '허브', scrapCount: 99),
        for (var i = 0; i < 10; i++)
          ConceptNode(id: 'n$i', name: '이웃$i', scrapCount: 10 - i),
      ],
      links: [for (var i = 0; i < 10; i++) ConceptLink('hub', 'n$i')],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conceptGraphRepositoryProvider.overrideWithValue(_StaticGraph(hub)),
        ],
        child: const AnomieApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('마인드맵'));
    await tester.pumpAndSettle();

    // 6자리 중 5개는 개념, 마지막 자리는 나머지 5개를 묶은 "+5".
    expect(find.bySemanticsLabel('이웃4'), findsOneWidget);
    expect(find.bySemanticsLabel('이웃5'), findsNothing);
    await tester.tap(find.bySemanticsLabel('숨은 개념 5개 보기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('허브에 연결된 개념'), findsOneWidget);
    await tester.tap(find.text('이웃7'));
    await tester.pumpAndSettle();

    expect(summaryCardText('스크랩 3  연결 1  제안 0'), findsOneWidget);
    expect(find.byTooltip('이전 개념'), findsOneWidget);
  });
}

/// 고정된 그래프만 돌려주는 저장소. 나머지 동작은 가짜 저장소를 그대로 쓴다.
class _StaticGraph extends FakeConceptGraphRepository {
  _StaticGraph(this.graph) : super(delay: Duration.zero);

  final ConceptGraph graph;

  @override
  Future<ConceptGraph> fetchGraph() async => graph;
}
