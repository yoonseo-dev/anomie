import 'package:client/features/scrap/tag_review_controller.dart';
import 'package:client/shared/data/concept_graph_repository.dart';
import 'package:client/shared/data/scrap_analysis_repository.dart';
import 'package:client/shared/data/scrap_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late FakeScrapRepository scraps;

  TagReviewController controller() =>
      container.read(tagReviewControllerProvider.notifier);
  TagReviewState state() => container.read(tagReviewControllerProvider);

  setUp(() async {
    scraps = FakeScrapRepository(delay: Duration.zero);
    container = ProviderContainer(
      overrides: [
        scrapRepositoryProvider.overrideWithValue(scraps),
        conceptGraphRepositoryProvider.overrideWithValue(
          FakeConceptGraphRepository(delay: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);

    final analysis = await const FakeScrapAnalysisRepository(
      delay: Duration.zero,
    ).analyzeArticle('https://hani.co.kr/arti/society/1162');
    container.read(latestAnalysisProvider.notifier).set(analysis);
    await container.read(conceptGraphProvider.future);
    // autoDispose provider가 테스트 중에 사라지지 않게 붙잡아 둔다.
    container.listen(tagReviewControllerProvider, (_, _) {});
  });

  test('분석 결과의 태그 3개로 시작한다', () {
    expect(state().drafts.map((d) => d.name), ['상대적 박탈감', '아노미', '이행기 지연']);
    expect(state().drafts.map((d) => d.showsAsNew), [false, false, true]);
    expect(state().canSave, isTrue);
  });

  test('비슷한 내 태그로 바꾸고, 같은 칩을 다시 누르면 되돌린다', () {
    controller().toggleReplacement(2, '불안정 노동');
    expect(state().drafts[2].finalName, '불안정 노동');
    expect(state().drafts[2].showsAsNew, isFalse);

    controller().toggleReplacement(2, '위험사회');
    expect(state().drafts[2].finalName, '위험사회');

    controller().toggleReplacement(2, '위험사회');
    expect(state().drafts[2].finalName, '이행기 지연');
    expect(state().drafts[2].showsAsNew, isTrue);
  });

  test('이름을 내 개념 이름으로 고치면 내 태그, 처음 보는 이름이면 새 태그가 된다', () {
    controller().rename(2, '  아비투스 ');
    expect(state().drafts[2].name, '아비투스');
    expect(state().drafts[2].showsAsNew, isFalse);

    controller().rename(0, '청년 이행');
    expect(state().drafts[0].showsAsNew, isTrue);

    controller().rename(0, '   ');
    expect(state().drafts[0].name, '청년 이행');
  });

  test('빼고 되돌리면 개수와 저장 가능 여부가 따라 바뀐다', () {
    controller().remove(0);
    controller().remove(1);
    expect(state().keptCount, 1);

    controller().remove(2);
    expect(state().keptCount, 0);
    expect(state().canSave, isFalse);

    controller().restore(1);
    expect(state().keptCount, 1);
    expect(state().canSave, isTrue);
  });

  test('저장하면 남은 태그 이름(중복 없이)으로 최근 스크랩 맨 앞에 추가된다', () async {
    controller().remove(0);
    controller().toggleReplacement(2, '불안정 노동');
    controller().rename(1, '불안정 노동');

    expect(await controller().save(), isTrue);

    final recent = await scraps.fetchRecent();
    expect(recent.first.title, '청년 고용률 4년 만에 하락 전환, 첫 일자리까지 평균 11개월');
    expect(recent.first.conceptNames, ['불안정 노동']);
  });
}
