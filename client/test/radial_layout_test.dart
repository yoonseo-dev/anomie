import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:client/shared/data/concept_graph_repository.dart';
import 'package:client/shared/models/concept_graph.dart';
import 'package:client/shared/widgets/concept_graph/radial_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트용 크기: 원은 스크랩 수에 비례, 점은 이름표 몫으로 자리를 넓게 잡는다.
NodeMetrics _measure(
  ConceptNode node,
  GraphNodeRole role,
  int degree,
  int maxScrap,
) => switch (role) {
  GraphNodeRole.focus => (radius: 59.0, footprint: 66.0),
  GraphNodeRole.circle => (
    radius: 27.0 + node.scrapCount * 4,
    footprint: 27.0 + node.scrapCount * 4,
  ),
  GraphNodeRole.point => (radius: 5.0, footprint: 5.0 + 60),
  GraphNodeRole.overflow => (radius: 22.0, footprint: 22.0),
};

const _minEdge = 28.0;
const _gap = 10.0;

GraphLayout _layout(ConceptGraph g, String focusId) => radialLayout(
  g,
  focusId,
  measure: _measure,
  maxPrimary: 6,
  maxChildrenPerNode: 2,
  minEdge: _minEdge,
  gap: _gap,
);

/// [count]개 개념과 무작위 연결을 가진 그래프. 'c0'은 연결이 아주 많은 허브다.
ConceptGraph _generate(int count, {int seed = 7}) {
  final rnd = math.Random(seed);
  final nodes = [
    for (var i = 0; i < count; i++)
      ConceptNode(
        id: 'c$i',
        name: '개념 ${'가나다라마바사'.substring(0, 1 + i % 6)} $i',
        scrapCount: rnd.nextInt(4) == 0 ? 0 : rnd.nextInt(6) + 1,
      ),
  ];
  final pairs = <String>{};
  final links = <ConceptLink>[];
  void link(int a, int b) {
    if (a == b) return;
    final key = a < b ? '$a-$b' : '$b-$a';
    if (!pairs.add(key)) return;
    links.add(
      ConceptLink(
        'c$a',
        'c$b',
        status: rnd.nextInt(5) == 0
            ? ConceptLinkStatus.suggested
            : ConceptLinkStatus.confirmed,
      ),
    );
  }

  for (var i = 1; i < count; i++) {
    if (i <= count ~/ 3) link(0, i); // 허브
    for (var k = 0; k < 3; k++) {
      link(i, rnd.nextInt(count));
    }
  }
  return ConceptGraph(nodes: nodes, links: links);
}

void _expectNoOverlap(GraphLayout layout) {
  final nodes = layout.nodes;
  for (var i = 0; i < nodes.length; i++) {
    for (var j = i + 1; j < nodes.length; j++) {
      final a = nodes[i], b = nodes[j];
      expect(
        (a.position - b.position).distance,
        greaterThanOrEqualTo(a.footprint + b.footprint - 1e-6),
        reason: '${a.node.name}(${a.hop}) / ${b.node.name}(${b.hop})',
      );
    }
  }
}

void _expectMinEdges(GraphLayout layout) {
  final byId = {for (final n in layout.nodes) n.node.id: n};
  for (final n in layout.nodes) {
    if (n.hop == 0) continue;
    // 1단계는 가운데와, 2단계는 부모와 이어진다.
    final other = n.hop == 1 ? layout.nodes.first : byId[n.parentId]!;
    final edge =
        (n.position - other.position).distance - n.radius - other.radius;
    expect(edge, greaterThanOrEqualTo(_minEdge - 1e-6), reason: n.node.name);
  }
}

void main() {
  group('가짜 데이터', () {
    late ConceptGraph g;
    setUpAll(() async {
      g = await FakeConceptGraphRepository(delay: Duration.zero).fetchGraph();
    });

    test('가운데 개념은 원점에, 1단계는 2단계보다 안쪽에 놓인다', () {
      final layout = _layout(g, 'anomie');
      expect(layout.nodes.first.node.id, 'anomie');
      expect(layout.nodes.first.position, Offset.zero);

      final hop1 = layout.nodes.where((n) => n.hop == 1);
      final hop2 = layout.nodes.where((n) => n.hop == 2);
      expect(hop1, hasLength(6));
      for (final a in hop1) {
        for (final b in hop2) {
          expect(a.position.distance, lessThan(b.position.distance));
        }
      }
    });

    test('겹치지 않고 선 길이가 최소값 이상이다', () {
      for (final focus in ['anomie', 'precarious-labor', 'cultural-capital']) {
        final layout = _layout(g, focus);
        _expectNoOverlap(layout);
        _expectMinEdges(layout);
      }
    });

    test('2단계 개념은 부모 수 상한을 넘으면 "+N"으로 묶인다', () {
      final layout = radialLayout(
        g,
        'anomie',
        measure: _measure,
        maxChildrenPerNode: 1,
      );
      final overflow = layout.nodes.where(
        (n) => n.role == GraphNodeRole.overflow,
      );
      // 상대적 박탈감(자식 2)과 불안정 노동(자식 2)만 넘친다.
      expect(
        overflow.map((n) => n.parentId),
        unorderedEquals(['relative-deprivation', 'precarious-labor']),
      );
      expect(overflow.every((n) => n.hiddenCount == 2), isTrue);
    });

    test('없는 개념을 가운데로 주면 빈 배치를 돌려준다', () {
      expect(_layout(g, 'nope').nodes, isEmpty);
    });
  });

  group('개념이 많을 때', () {
    for (final count in [30, 100, 300]) {
      test('$count개: 상한을 지키고, 겹치지 않고, 숨긴 개념까지 합하면 이웃 수와 같다', () {
        final g = _generate(count);
        for (final focus in ['c0', 'c1', 'c${count ~/ 2}', 'c${count - 1}']) {
          final layout = _layout(g, focus);

          final hop1 = layout.nodes.where((n) => n.hop == 1).toList();
          expect(hop1.length, lessThanOrEqualTo(6), reason: focus);
          for (final p in hop1) {
            final children = layout.nodes.where(
              (n) => n.hop == 2 && n.parentId == p.node.id,
            );
            expect(children.length, lessThanOrEqualTo(2), reason: focus);
          }

          final neighbors = g
              .linksOf(focus)
              .map((l) => l.otherEnd(focus))
              .toSet();
          final shownNeighbors = hop1
              .where((n) => n.role != GraphNodeRole.overflow)
              .length;
          expect(
            shownNeighbors + (layout.hidden[focus]?.length ?? 0),
            neighbors.length,
            reason: focus,
          );

          _expectNoOverlap(layout);
          _expectMinEdges(layout);
        }
      });
    }

    test('같은 데이터면 늘 같은 배치가 나온다', () {
      final g = _generate(100);
      final a = _layout(g, 'c0').nodes.map((n) => (n.node.id, n.position));
      final b = _layout(g, 'c0').nodes.map((n) => (n.node.id, n.position));
      expect(a.toList(), b.toList());
    });

    test('범위는 모든 개념의 자리를 포함한다', () {
      final layout = _layout(_generate(300), 'c0');
      for (final n in layout.nodes) {
        final rect = Rect.fromCircle(center: n.position, radius: n.footprint);
        expect(
          layout.bounds.inflate(1e-6).contains(rect.topLeft) &&
              layout.bounds.inflate(1e-6).contains(rect.bottomRight),
          isTrue,
        );
      }
    });
  });
}
