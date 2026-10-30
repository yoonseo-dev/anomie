import 'dart:typed_data';

import 'package:client/features/scrap/tag_review_controller.dart';
import 'package:client/shared/data/concept_graph_repository.dart';
import 'package:client/shared/data/scrap_analysis_repository.dart';
import 'package:client/shared/data/scrap_repository.dart';
import 'package:client/shared/models/scrap.dart';
import 'package:client/shared/models/scrap_analysis.dart';
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

  group('저장할 태그 (approvedTags)', () {
    // 새 태그 2개(설명 있음) + 기존 태그 1개
    setUp(() {
      container
          .read(latestAnalysisProvider.notifier)
          .set(
            const ScrapAnalysis(
              source: ScrapSource.article,
              title: '기사',
              origin: '한겨레',
              sourceName: '한겨레',
              tags: [
                SuggestedTag(
                  name: '아노미',
                  reason: 'r1',
                  explanation: 'e1',
                  category: '사회학',
                ),
                SuggestedTag(
                  name: '이행기 지연',
                  reason: 'r2',
                  isNew: true,
                  category: '사회학',
                  description: '이행기 지연 설명',
                  similarExisting: ['불안정 노동'],
                ),
                SuggestedTag(
                  name: '청년 고립',
                  reason: 'r3',
                  isNew: true,
                  description: '청년 고립 설명',
                ),
              ],
            ),
          );
      container.invalidate(tagReviewControllerProvider);
    });

    test('제안 그대로의 새 태그만 AI 설명·분야를 보내고, 기존 태그는 이름·이유·풀이만', () {
      final tags = controller().approvedTags;

      expect(tags.map((t) => t.toJson()), [
        {'name': '아노미', 'reason': 'r1', 'explanation': 'e1'},
        {
          'name': '이행기 지연',
          'reason': 'r2',
          'explanation': '',
          'category': '사회학',
          'description': '이행기 지연 설명',
        },
        {
          'name': '청년 고립',
          'reason': 'r3',
          'explanation': '',
          'description': '청년 고립 설명',
        },
      ]);
    });

    test('비슷한 내 태그로 바꾸면 설명을 빼고, 이름을 고친 새 태그도 설명을 뺀다', () {
      controller().toggleReplacement(1, '불안정 노동');
      controller().rename(2, '청년 단절');

      final tags = controller().approvedTags;

      expect(tags[1].name, '불안정 노동');
      expect(tags[1].description, isNull);
      expect(tags[1].category, isNull);
      expect(tags[2].name, '청년 단절');
      expect(tags[2].description, isNull); // 원래 설명은 '청년 고립'에 대한 것
    });

    test('같은 이름이 둘이면 처음 것만 남긴다', () {
      controller().rename(2, '아노미');
      expect(controller().approvedTags.map((t) => t.name), ['아노미', '이행기 지연']);
    });
  });

  group('책 근거 문장', () {
    setUp(() async {
      final analysis =
          await const FakeScrapAnalysisRepository(
            delay: Duration.zero,
          ).analyzeBookPage(
            photo: PagePhoto(bytes: Uint8List(1)),
            title: '자살론',
          );
      container.read(latestAnalysisProvider.notifier).set(analysis);
      container.invalidate(tagReviewControllerProvider);
    });

    test('OCR 텍스트에서 찾지 못한 근거 문장만 확인 필요', () {
      expect(state().drafts.map((d) => d.excerptNeedsCheck), [false, true]);
    });

    test('근거 문장을 고치면 확인 필요가 사라지고, 고친 문장으로 저장한다', () {
      controller().editExcerpt(1, '  사회가 개인을 붙잡는 힘이 약해질수록 자살은 늘어난다  ');

      expect(state().drafts[1].excerptNeedsCheck, isFalse);
      expect(controller().approvedTags.map((t) => t.excerpt), [
        '규범이 힘을 잃으면 욕망은 더 이상 한계를 알지 못한다.',
        '사회가 개인을 붙잡는 힘이 약해질수록 자살은 늘어난다',
      ]);
    });

    test('빈 근거 문장으로는 고치지 않는다', () {
      controller().editExcerpt(0, '   ');
      expect(state().drafts[0].excerpt, '규범이 힘을 잃으면 욕망은 더 이상 한계를 알지 못한다.');
    });

    test('이름을 고쳐도 고친 근거 문장은 그대로 남는다', () {
      controller().editExcerpt(1, '고친 문장');
      controller().rename(1, '사회 통합');

      expect(state().drafts[1].excerpt, '고친 문장');
      expect(state().drafts[1].excerptNeedsCheck, isFalse);
    });
  });
}
