import 'package:client/app.dart';
import 'package:client/features/concept/concept_detail_screen.dart';
import 'package:client/features/manage/manage_screen.dart';
import 'package:client/shared/data/concept_graph_repository.dart';
import 'package:client/shared/data/concept_repository.dart';
import 'package:client/shared/data/scrap_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> openManage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conceptGraphRepositoryProvider.overrideWithValue(
            FakeConceptGraphRepository(delay: Duration.zero),
          ),
          scrapRepositoryProvider.overrideWithValue(
            FakeScrapRepository(delay: Duration.zero),
          ),
          conceptRepositoryProvider.overrideWithValue(
            FakeConceptRepository(delay: Duration.zero),
          ),
        ],
        child: const AnomieApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('관리'));
    await tester.pumpAndSettle();
    expect(find.byType(ManageScreen), findsOneWidget);
  }

  Finder inManage(Finder f) =>
      find.descendant(of: find.byType(ManageScreen), matching: f);

  Future<void> openRelations(WidgetTester tester) async {
    await tester.tap(inManage(find.text('관계  15')));
    await tester.pumpAndSettle();
  }

  testWidgets('태그 탭: 정렬 칩을 바꾸면 순서가 바뀐다', (tester) async {
    await openManage(tester);

    double top(String name) => tester.getTopLeft(inManage(find.text(name))).dy;

    // 스크랩 많은 순: 아노미(3)가 공론장(0)보다 위.
    expect(top('아노미'), lessThan(top('공론장')));

    await tester.tap(inManage(find.text('이름순')));
    await tester.pumpAndSettle();
    expect(top('계급 재생산'), lessThan(top('아노미')));

    await tester.tap(inManage(find.text('최근 추가순')));
    await tester.pumpAndSettle();
    // 불안정 노동(10/9)이 아노미(9/21)보다 위.
    expect(top('불안정 노동'), lessThan(top('아노미')));
  });

  testWidgets('태그 탭: 삭제는 확인 후 목록과 개수에서 사라진다', (tester) async {
    await openManage(tester);

    await tester.tap(inManage(find.text('삭제')).first); // 아노미
    await tester.pumpAndSettle();
    expect(find.text('아노미 태그를 삭제할까요?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();

    expect(inManage(find.text('아노미')), findsNothing);
    expect(inManage(find.text('태그  15')), findsOneWidget);
  });

  testWidgets('태그 탭: 병합할 태그를 고르고 확인하면 합쳐진다', (tester) async {
    await openManage(tester);

    // 스크랩 많은 순에서 소외 줄의 병합을 누른다.
    final row = find.ancestor(
      of: inManage(find.text('소외')),
      matching: find.byType(Row),
    );
    await tester.tap(find.descendant(of: row.first, matching: find.text('병합')));
    await tester.pumpAndSettle();
    expect(find.text('소외 병합하기'), findsOneWidget);

    await tester.tap(find.text('아노미').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '병합'));
    await tester.pumpAndSettle();

    expect(inManage(find.text('소외')), findsNothing);
    expect(find.text('아노미에 합쳤어요'), findsOneWidget);
  });

  testWidgets('관계 탭: 승인하면 연결됨으로 옮겨간다', (tester) async {
    await openManage(tester);
    await openRelations(tester);

    expect(inManage(find.text('3')), findsWidgets); // 확인 기다리는 제안 3
    await tester.tap(inManage(find.text('승인')).first);
    await tester.pumpAndSettle();

    expect(find.text('연결했어요'), findsOneWidget);
    expect(inManage(find.text('승인')), findsNWidgets(2));
    expect(inManage(find.text('13')), findsOneWidget); // 연결됨 12 → 13
  });

  testWidgets('관계 탭: 거절은 되돌릴 수 있다', (tester) async {
    await openManage(tester);
    await openRelations(tester);

    await tester.tap(inManage(find.text('거절')).first);
    await tester.pumpAndSettle();
    expect(inManage(find.text('승인')), findsNWidgets(2));

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(inManage(find.text('승인')), findsNWidgets(3));
  });

  testWidgets('관계 탭: ··· 메뉴로 이유를 수정하고 연결을 끊는다', (tester) async {
    await openManage(tester);
    await openRelations(tester);

    await tester.tap(find.byTooltip('아노미 ── 상대적 박탈감 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('수정하기'), findsWidgets);
    await tester.tap(find.text('수정하기').last);
    await tester.pumpAndSettle();
    expect(find.text('연결 이유 수정하기'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '새 연결 이유');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('아노미 ── 상대적 박탈감 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('연결 끊기'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('아노미 ── 상대적 박탈감 메뉴'), findsNothing);
    expect(find.text('연결을 끊었어요'), findsOneWidget);
  });

  testWidgets('상세의 제안 확인하기는 관계 탭을 연 채로 관리 화면을 보여 준다', (tester) async {
    await openManage(tester);
    // 태그 탭에서 아노미 상세로 들어간다.
    await tester.tap(inManage(find.text('아노미')));
    await tester.pumpAndSettle();
    expect(find.byType(ConceptDetailScreen), findsOneWidget);

    final link = find.text('제안 확인하기').first;
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.byType(ConceptDetailScreen), findsNothing);
    expect(inManage(find.text('확인 기다리는 제안')), findsOneWidget);
  });
}
