import 'package:client/shared/data/concept_detail_provider.dart';
import 'package:client/shared/data/concept_graph_repository.dart';
import 'package:client/shared/data/concept_repository.dart';
import 'package:client/shared/data/scrap_repository.dart';
import 'package:client/shared/models/concept_detail.dart';
import 'package:client/shared/models/scrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late FakeScrapRepository scraps;
  late FakeConceptRepository concepts;

  Future<ConceptDetail?> detail(String id) async {
    final sub = container.listen(conceptDetailProvider(id), (_, _) {});
    addTearDown(sub.close);
    return container.read(conceptDetailProvider(id).future);
  }

  setUp(() {
    scraps = FakeScrapRepository(
      delay: Duration.zero,
      now: () => DateTime(2026, 10, 12),
    );
    concepts = FakeConceptRepository(delay: Duration.zero);
    container = ProviderContainer(
      overrides: [
        scrapRepositoryProvider.overrideWithValue(scraps),
        conceptRepositoryProvider.overrideWithValue(concepts),
        conceptGraphRepositoryProvider.overrideWithValue(
          FakeConceptGraphRepository(delay: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('아노미: 스크랩은 최근 것부터, 연결은 확정 먼저, 처음 등장은 가장 오래된 스크랩', () async {
    final d = (await detail('anomie'))!;

    expect(d.scraps.map((s) => s.sourceName), ['경향신문', '한겨레', '자살론']);
    expect(d.confirmedCount, 4);
    expect(d.suggestedCount, 2);
    expect(d.links.take(4).every((l) => !l.link.isSuggested), isTrue);
    expect(d.firstScrap?.sourceName, '자살론');
    expect(d.description?.byAi, isTrue);
    expect(d.scraps.first.explanations['아노미'], '플랫폼 규칙이 수시로 바뀌어 기댈 기준이 없다는 점.');
  });

  test('없는 개념이면 null', () async {
    expect(await detail('nope'), isNull);
  });

  test('설명을 수정하고 다시 불러오면 직접 쓴 설명이 된다', () async {
    await detail('anomie');
    await concepts.updateDescription('anomie', '규범이 흔들리는 상태.');
    container.invalidate(conceptDetailProvider('anomie'));

    final d = (await detail('anomie'))!;
    expect(d.description?.text, '규범이 흔들리는 상태.');
    expect(d.description?.byAi, isFalse);
  });

  test('새로 저장한 스크랩이 맨 앞에 붙는다', () async {
    await scraps.save(
      source: ScrapSource.article,
      title: '새 기사',
      origin: '한겨레',
      originDetail: '한겨레 · 10월 12일',
      sourceName: '한겨레',
      conceptNames: ['아노미'],
      explanations: {'아노미': '새 풀이'},
    );
    container.invalidate(conceptDetailProvider);

    final d = (await detail('anomie'))!;
    expect(d.scraps, hasLength(4));
    expect(d.scraps.first.title, '새 기사');
    expect(d.firstScrap?.sourceName, '자살론');
  });
}
