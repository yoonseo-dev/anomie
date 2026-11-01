import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

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

GraphLayout _layout(ConceptGraph g, String focusId, {GraphLayout? previous}) =>
    radialLayout(
      g,
      focusId,
      measure: _measure,
      maxPrimary: 6,
      maxChildrenPerNode: 2,
      minEdge: _minEdge,
      gap: _gap,
      previous: previous == null
          ? null
          : {
              // 화면 코드(ConceptGraphStyle.layoutFor)처럼 "+N" 묶음은 빼고 넘긴다
              for (final n in previous.nodes)
                if (n.role != GraphNodeRole.overflow) n.node.id: n.position,
            },
    );

Offset _pos(GraphLayout l, String id) =>
    l.nodes.firstWhere((n) => n.node.id == id).position;

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

  group('개념을 타고 들어갈 때 방향 유지', () {
    // 11-01 사용자 데이터와 같은 모양: 지위 불안–상대적 박탈감–대중소비사회, 지위 불안–도구화·냉소주의
    final g = ConceptGraph(
      nodes: const [
        ConceptNode(id: 'status', name: '불안과 지위 경쟁', scrapCount: 3),
        ConceptNode(id: 'deprivation', name: '상대적 박탈감', scrapCount: 2),
        ConceptNode(id: 'consumer', name: '대중소비사회', scrapCount: 1),
        ConceptNode(id: 'tool', name: '도구화', scrapCount: 1),
        ConceptNode(id: 'cynic', name: '도덕적 냉소주의', scrapCount: 1),
      ],
      links: [
        ConceptLink('status', 'deprivation'),
        ConceptLink('deprivation', 'consumer'),
        ConceptLink('status', 'tool', status: ConceptLinkStatus.suggested),
        ConceptLink('status', 'cynic', status: ConceptLinkStatus.suggested),
      ],
    );

    double angleOf(Offset p) => math.atan2(p.dy, p.dx);

    /// 두 각도가 [tolerance] 안에서 같은 방향인지 (한 바퀴 차이는 무시).
    bool sameDirection(double a, double b, {double tolerance = 0.35}) {
      final d = (a - b) % (2 * math.pi);
      return d < tolerance || d > 2 * math.pi - tolerance;
    }

    test('눌러 들어온 개념의 반대쪽에 직전 가운데 개념이 놓인다', () {
      // 상대적 박탈감 → (연결 3개인) 불안과 지위 경쟁으로 들어간다
      final first = _layout(g, 'deprivation');
      final tapped = _pos(first, 'status');

      final next = _layout(g, 'status', previous: first);

      expect(
        sameDirection(angleOf(_pos(next, 'deprivation')), angleOf(-tapped)),
        isTrue,
      );
    });

    test('다른 개념도 새 가운데에서 본 예전 시계 방향 순서를 지키고, 되돌아오면 제자리다', () {
      final big = _generate(80);
      final first = _layout(big, 'c0');
      // 연결이 3개 이상인 1단계 개념으로 들어간다
      final into = first.nodes
          .where((n) => n.hop == 1 && n.role != GraphNodeRole.overflow)
          .firstWhere((n) => big.linksOf(n.node.id).length >= 3);
      final x = into.node.id;
      final next = _layout(big, x, previous: first);

      // 예전 화면에도 있던 1단계 개념들: x에서 본 예전 각도 순서 == 새 화면의 시계 방향 순서
      List<String> clockwiseFrom(List<(String, double)> items) {
        final sorted = [...items]..sort((a, b) => a.$2.compareTo(b.$2));
        final ids = [for (final e in sorted) e.$1];
        final start = ids.indexOf('c0');
        return [...ids.sublist(start), ...ids.sublist(0, start)];
      }

      final shared = [
        for (final n in next.nodes.where(
          (n) => n.hop == 1 && n.role != GraphNodeRole.overflow,
        ))
          if (first.nodes.any((m) => m.node.id == n.node.id)) n.node.id,
      ];
      expect(shared, contains('c0'));
      expect(
        clockwiseFrom([for (final id in shared) (id, angleOf(_pos(next, id)))]),
        clockwiseFrom([
          for (final id in shared)
            (id, angleOf(_pos(first, id) - _pos(first, x))),
        ]),
      );

      // 되돌아오면 x는 처음 자리 방향에 다시 놓인다
      final back = _layout(big, 'c0', previous: next);
      expect(
        sameDirection(angleOf(_pos(back, x)), angleOf(into.position)),
        isTrue,
      );
    });

    test('1단계가 1~2개면 좌우로 놓는다 (세로 한 줄이 되지 않는다)', () {
      // 대중소비사회는 연결이 하나뿐이다
      final single = _pos(_layout(g, 'consumer'), 'deprivation');
      expect(single.dy.abs(), lessThan(1e-6));
      expect(single.dx, greaterThan(0));

      // 상대적 박탈감은 두 개념과 이어지고, 딸린 개념 수가 달라도 수평이다
      final two = _layout(g, 'deprivation');
      for (final id in ['status', 'consumer']) {
        expect(_pos(two, id).dy.abs(), lessThan(1e-6));
      }
      expect(_pos(two, 'status').dx.sign, isNot(_pos(two, 'consumer').dx.sign));
    });

    test('직전 화면을 따라가도 1~2개면 좌우를 고른다', () {
      final first = _layout(g, 'status');
      final next = _layout(g, 'deprivation', previous: first);
      for (final id in ['status', 'consumer']) {
        expect(_pos(next, id).dy.abs(), lessThan(1e-6));
      }
      // 직전 가운데는 눌러 들어온 반대쪽(좌/우)에 있다
      expect(_pos(next, 'status').dx.sign, -_pos(first, 'deprivation').dx.sign);
    });

    test('직전 화면에 없던 개념으로 가면(숨은 개념에서 고름) 기본 배치를 쓴다', () {
      final first = _layout(g, 'status');
      // 대중소비사회만 빼고 직전 화면을 흉내 낸다 (상대적 박탈감은 원점 = 직전 가운데)
      final previous = _layout(g, 'deprivation');
      final hiddenBefore = radialLayout(
        g,
        'consumer',
        measure: _measure,
        previous: {
          for (final n in previous.nodes)
            if (n.node.id != 'consumer') n.node.id: n.position,
        },
      );
      expect(_pos(hiddenBefore, 'deprivation').dy.abs(), lessThan(1e-6));
      expect(first.nodes, isNotEmpty);
    });

    test('같은 가운데로 다시 계산해도(데이터 갱신 등) 배치가 그대로다', () {
      final first = _layout(_generate(60), 'c0');
      final again = _layout(_generate(60), 'c0', previous: first);
      for (final n in first.nodes.where((n) => n.hop == 1)) {
        expect((_pos(again, n.node.id) - n.position).distance, lessThan(1e-6));
      }
    });
  });
}
