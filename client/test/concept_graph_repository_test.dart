import 'package:client/shared/data/concept_graph_repository.dart';
import 'package:client/shared/data/scrap_repository.dart';
import 'package:client/shared/models/concept_graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeConceptGraphRepository repo;

  setUp(() => repo = FakeConceptGraphRepository(delay: Duration.zero));

  ConceptLink? linkOf(ConceptGraph g, String a, String b) =>
      g.links.where((l) => l.connects(a, b)).firstOrNull;

  test('제안을 승인하면 확정된 연결이 된다', () async {
    await repo.approveLink('alienation', 'anomie'); // 방향은 상관없다.
    final g = await repo.fetchGraph();
    expect(linkOf(g, 'anomie', 'alienation')?.isSuggested, isFalse);
  });

  test('지운 연결은 원래 자리로 되돌릴 수 있다', () async {
    final before = (await repo.fetchGraph()).links;
    final removed = await repo.removeLink('anomie', 'alienation');
    expect(removed, isNotNull);
    expect(linkOf(await repo.fetchGraph(), 'anomie', 'alienation'), isNull);

    await repo.restoreLink(removed!.$1, removed.$2);
    final after = (await repo.fetchGraph()).links;
    expect(
      after.map((l) => (l.sourceId, l.targetId)),
      before.map((l) => (l.sourceId, l.targetId)),
    );
  });

  test('연결 이유를 고친다', () async {
    await repo.updateLinkReason('anomie', 'norm', '새 이유');
    expect(linkOf(await repo.fetchGraph(), 'anomie', 'norm')?.reason, '새 이유');
  });

  test('개념을 지우면 그 개념의 연결도 함께 사라진다', () async {
    await repo.deleteConcept('anomie');
    final g = await repo.fetchGraph();
    expect(g.node('anomie'), isNull);
    expect(g.linksOf('anomie'), isEmpty);
  });

  test('병합하면 연결이 옮겨지고, 겹치는 연결은 하나로, 둘 사이 연결은 사라진다', () async {
    // 소외 ── 아노미(제안), 소외 ── 규율 권력(확정)을 아노미로 합친다.
    await repo.mergeConcepts(fromId: 'alienation', intoId: 'anomie');
    final g = await repo.fetchGraph();

    expect(g.node('alienation'), isNull);
    expect(g.node('anomie')!.scrapCount, 4); // 3 + 1
    expect(linkOf(g, 'anomie', 'disciplinary-power')?.isSuggested, isFalse);
    expect(g.links.where((l) => l.touches('alienation')), isEmpty);
    // 아노미 자기 자신으로 가는 연결은 생기지 않는다.
    expect(g.links.where((l) => l.sourceId == l.targetId), isEmpty);
  });

  group('스크랩 태그', () {
    late FakeScrapRepository scraps;
    setUp(() => scraps = FakeScrapRepository(delay: Duration.zero));

    test('이름을 바꾸면 겹치는 태그는 하나로 합쳐지고 풀이도 옮겨진다', () async {
      // s1에는 아노미와 상대적 박탈감이 함께 붙어 있다.
      await scraps.renameConcept('상대적 박탈감', '아노미');
      final s1 = (await scraps.fetchRecent()).first;
      expect(s1.conceptNames, ['아노미']);
      expect(s1.explanations.keys, ['아노미']);

      await scraps.renameConcept('불안정 노동', '플랫폼 노동');
      final s3 = (await scraps.fetchByConcept('플랫폼 노동')).single;
      expect(s3.explanations['플랫폼 노동'], isNotNull);
    });

    test('태그를 빼면 스크랩과 풀이에서 모두 빠진다', () async {
      await scraps.removeConcept('아노미');
      expect(await scraps.fetchByConcept('아노미'), isEmpty);
      final s1 = (await scraps.fetchRecent()).first;
      expect(s1.explanations.containsKey('아노미'), isFalse);
    });
  });
}
