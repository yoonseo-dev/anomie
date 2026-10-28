import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../../models/concept_graph.dart';

enum GraphNodeRole {
  /// 가운데 개념.
  focus,

  /// 스크랩이 있는 개념: 이름이 안에 들어가는 원.
  circle,

  /// 스크랩이 없는 개념: 작은 점 + 옆 이름표.
  point,

  /// 상한을 넘어 숨긴 개념 묶음: "+N" 점선 원.
  overflow,
}

/// 원의 실제 반지름과, 이름표까지 포함해 다른 개념과 띄워야 하는 반지름.
typedef NodeMetrics = ({double radius, double footprint});

/// 개념 하나의 크기를 정한다. [maxScrap]은 이번에 놓일 원 개념 중 가장 큰 스크랩 수.
typedef NodeMeasure =
    NodeMetrics Function(
      ConceptNode node,
      GraphNodeRole role,
      int degree,
      int maxScrap,
    );

class PlacedNode {
  const PlacedNode({
    required this.node,
    required this.role,
    required this.hop,
    required this.degree,
    required this.position,
    required this.radius,
    required this.footprint,
    this.parentId,
    this.hiddenCount = 0,
  });

  final ConceptNode node;
  final GraphNodeRole role;

  /// 가운데 개념에서 몇 단계 떨어져 있는지 (0, 1, 2).
  final int hop;

  /// 그래프 전체에서 이 개념에 붙은 연결 수.
  final int degree;

  /// 가운데 개념을 (0, 0)으로 둔 픽셀 위치.
  final Offset position;

  final double radius;
  final double footprint;

  /// 2단계 개념과 "+N" 묶음의 부모 개념 id. 가운데 개념에 딸린 묶음이면 가운데 개념 id.
  final String? parentId;

  /// "+N" 묶음이 숨긴 개념 수.
  final int hiddenCount;

  /// 점 이름표를 바깥쪽(가운데에서 먼 쪽)으로 붙일 때 오른쪽인지.
  bool get labelOnRight => position.dx >= 0;
}

class GraphLayout {
  const GraphLayout({
    required this.nodes,
    required this.links,
    required this.hidden,
    required this.ring1,
    required this.ring2,
    required this.bounds,
  });

  final List<PlacedNode> nodes;

  /// 배치된 개념끼리의 연결 + 부모와 "+N" 묶음을 잇는 점선.
  final List<ConceptLink> links;

  /// "+N" 묶음 안에 숨긴 개념. 키는 묶음의 부모 id.
  final Map<String, List<ConceptNode>> hidden;

  /// 1단계·2단계 고리 반지름 (2단계가 없으면 ring2 == ring1).
  final double ring1;
  final double ring2;

  /// 이름표까지 포함한 전체 범위 (가운데 개념 기준 좌표).
  final Rect bounds;

  static const empty = GraphLayout(
    nodes: [],
    links: [],
    hidden: {},
    ring1: 0,
    ring2: 0,
    bounds: Rect.zero,
  );
}

/// "+N" 묶음의 id. 실제 개념 id와 겹치지 않게 접두어를 붙인다.
String overflowIdFor(String parentId) => '__more__$parentId';

/// [focusId]를 가운데에 두고 둥글게 펼친 배치를 계산한다.
///
/// 개념이 수백 개여도 겹치지 않도록 다음 원칙을 따른다.
/// - 한 화면에 놓는 수에 상한을 둔다: 1단계 [maxPrimary]개, 부모당 2단계
///   [maxChildrenPerNode]개. 넘치는 개념은 "+N" 묶음 하나로 대신한다.
/// - 각도는 딸린 2단계 개념 수에 비례해 나눈다. 2단계 개념은 부모 몫의 각도 안에만 놓인다.
/// - 고리 반지름은 고정 비율이 아니라, 이웃한 개념의 크기(이름표 포함)와 [gap],
///   최소 선 길이 [minEdge]를 만족하는 값으로 계산한다.
/// - 같은 데이터면 늘 같은 배치가 나오도록 놓는 순서를 고정한다
///   (스크랩 수 → 연결 수 → 이름).
GraphLayout radialLayout(
  ConceptGraph graph,
  String focusId, {
  required NodeMeasure measure,
  int maxPrimary = 6,
  int maxChildrenPerNode = 2,
  double minEdge = 24,
  double gap = 8,
  bool showOverflow = true,
}) {
  final focus = graph.node(focusId);
  if (focus == null) return GraphLayout.empty;

  int degreeOf(String id) => graph.linksOf(id).length;

  int byPriority(ConceptNode a, ConceptNode b) {
    final s = b.scrapCount.compareTo(a.scrapCount);
    if (s != 0) return s;
    final d = degreeOf(b.id).compareTo(degreeOf(a.id));
    if (d != 0) return d;
    return a.name.compareTo(b.name);
  }

  List<ConceptNode> neighborsOf(String id, Set<String> exclude) {
    final seen = <String>{};
    final result = <ConceptNode>[];
    for (final l in graph.linksOf(id)) {
      final other = l.otherEnd(id);
      if (exclude.contains(other) || !seen.add(other)) continue;
      final n = graph.node(other);
      if (n != null) result.add(n);
    }
    return result..sort(byPriority);
  }

  /// [items] 중 [cap]개까지 보여 주고, 넘치면 마지막 자리를 "+N" 묶음에 내준다.
  (List<ConceptNode>, List<ConceptNode>) split(
    List<ConceptNode> items,
    int cap,
  ) {
    if (items.length <= cap) return (items, const []);
    // showOverflow가 false면 묶음 없이 cap개만 보여 준다 (작은 미리보기).
    final keep = showOverflow ? math.max(cap - 1, 0) : cap;
    return (items.sublist(0, keep), items.sublist(keep));
  }

  // ── 무엇을 놓을지 정한다 ──────────────────────────────────────────

  final allPrimary = neighborsOf(focusId, {focusId});
  final (primary, primaryHidden) = split(allPrimary, maxPrimary);
  final hidden = <String, List<ConceptNode>>{};
  if (primaryHidden.isNotEmpty && showOverflow) {
    hidden[focusId] = primaryHidden;
  }

  // 가운데 개념의 이웃은 1단계에만 둔다 (숨겨진 이웃도 2단계로 끌어오지 않는다).
  final taken = {focusId, for (final n in allPrimary) n.id};
  final childrenOf = <String, List<ConceptNode>>{};
  for (final p in primary) {
    final (shown, rest) = split(neighborsOf(p.id, taken), maxChildrenPerNode);
    childrenOf[p.id] = shown;
    taken.addAll(shown.map((n) => n.id));
    if (rest.isNotEmpty) {
      if (showOverflow) hidden[p.id] = rest;
      taken.addAll(rest.map((n) => n.id));
    }
  }

  GraphNodeRole roleOf(ConceptNode n) =>
      n.scrapCount > 0 ? GraphNodeRole.circle : GraphNodeRole.point;

  final maxScrap = [
    ...primary,
    for (final c in childrenOf.values) ...c,
  ].fold<int>(1, (m, n) => math.max(m, n.scrapCount));

  ConceptNode overflowNode(String parentId) {
    final count = hidden[parentId]!.length;
    return ConceptNode(id: overflowIdFor(parentId), name: '+$count');
  }

  NodeMetrics metricsOf(ConceptNode n, GraphNodeRole role) =>
      measure(n, role, degreeOf(n.id), maxScrap);

  // 1단계 자리: 실제 개념 + (넘치면) 가운데에 딸린 "+N".
  final ring1Items = <(ConceptNode, GraphNodeRole)>[
    for (final p in primary) (p, roleOf(p)),
    if (hidden.containsKey(focusId))
      (overflowNode(focusId), GraphNodeRole.overflow),
  ];

  // 2단계 자리: 부모별 자식 + (넘치면) 부모에 딸린 "+N".
  List<(ConceptNode, GraphNodeRole)> ring2ItemsOf(ConceptNode parent) => [
    for (final c in childrenOf[parent.id] ?? const <ConceptNode>[])
      (c, roleOf(c)),
    if (hidden.containsKey(parent.id))
      (overflowNode(parent.id), GraphNodeRole.overflow),
  ];

  final focusMetrics = metricsOf(focus, GraphNodeRole.focus);
  final placed = <PlacedNode>[
    PlacedNode(
      node: focus,
      role: GraphNodeRole.focus,
      hop: 0,
      degree: degreeOf(focusId),
      position: Offset.zero,
      radius: focusMetrics.radius,
      footprint: focusMetrics.footprint,
    ),
  ];

  if (ring1Items.isEmpty) {
    return GraphLayout(
      nodes: placed,
      links: const [],
      hidden: hidden,
      ring1: 0,
      ring2: 0,
      bounds: Rect.fromCircle(
        center: Offset.zero,
        radius: focusMetrics.footprint,
      ),
    );
  }

  // ── 각도: 딸린 2단계 수에 비례 ──────────────────────────────────────

  final ring1Metrics = [for (final (n, r) in ring1Items) metricsOf(n, r)];
  final ring2Items = [
    for (final (n, role) in ring1Items)
      role == GraphNodeRole.overflow
          ? <(ConceptNode, GraphNodeRole)>[]
          : ring2ItemsOf(n),
  ];
  final ring2Metrics = [
    for (final items in ring2Items)
      [for (final (n, r) in items) metricsOf(n, r)],
  ];

  final weights = [for (final items in ring2Items) math.max(1, items.length)];
  final totalWeight = weights.fold<int>(0, (a, b) => a + b);
  final spans = [for (final w in weights) 2 * math.pi * w / totalWeight];

  // 첫 개념이 왼쪽 위에서 시작하도록 회전시킨다 (Figma 배치와 비슷하게).
  final centers = <double>[];
  var cursor = -math.pi / 2 - spans.first;
  for (final s in spans) {
    centers.add(cursor + s / 2);
    cursor += s;
  }

  // ── 1단계 반지름: 선 길이와 이웃 간격을 모두 만족하는 최솟값 ─────────

  /// 두 원이 [angle]만큼 떨어져 있을 때 [need] 이상 벌어지려면 필요한 반지름.
  double radiusFor(double need, double angle) {
    final half = math.min(angle, math.pi) / 2;
    return need / (2 * math.max(math.sin(half), 1e-6));
  }

  var ring1 = 0.0;
  for (final m in ring1Metrics) {
    ring1 = math.max(ring1, focusMetrics.radius + minEdge + m.footprint);
  }
  final n1 = ring1Items.length;
  if (n1 > 1) {
    for (var i = 0; i < n1; i++) {
      final j = (i + 1) % n1;
      final angle = n1 == 2 ? math.pi : (spans[i] + spans[j]) / 2;
      ring1 = math.max(
        ring1,
        radiusFor(
          ring1Metrics[i].footprint + ring1Metrics[j].footprint + gap,
          angle,
        ),
      );
    }
  }

  // ── 2단계 반지름 ──────────────────────────────────────────────────

  final childAngles = <(int, double)>[]; // (부모 index, 각도)
  final childMetricsFlat = <NodeMetrics>[];
  for (var i = 0; i < n1; i++) {
    final m = ring2Items[i].length;
    for (var k = 0; k < m; k++) {
      // 부모 몫의 각도를 자식 수로 나눠 그 가운데에 놓는다.
      childAngles.add((
        i,
        centers[i] - spans[i] / 2 + spans[i] * (k + 0.5) / m,
      ));
      childMetricsFlat.add(ring2Metrics[i][k]);
    }
  }

  var ring2 = ring1;
  if (childAngles.isNotEmpty) {
    final maxRing1Footprint = ring1Metrics
        .map((m) => m.footprint)
        .reduce(math.max);
    final maxChildFootprint = childMetricsFlat
        .map((m) => m.footprint)
        .reduce(math.max);
    ring2 = ring1 + maxRing1Footprint + minEdge + maxChildFootprint;
    final c = childAngles.length;
    if (c > 1) {
      for (var a = 0; a < c; a++) {
        final b = (a + 1) % c;
        var angle = childAngles[b].$2 - childAngles[a].$2;
        if (angle <= 0) angle += 2 * math.pi;
        ring2 = math.max(
          ring2,
          radiusFor(
            childMetricsFlat[a].footprint + childMetricsFlat[b].footprint + gap,
            angle,
          ),
        );
      }
    }
  }

  // ── 위치 확정 ────────────────────────────────────────────────────

  Offset polar(double r, double angle) =>
      Offset(math.cos(angle), math.sin(angle)) * r;

  for (var i = 0; i < n1; i++) {
    final (node, role) = ring1Items[i];
    placed.add(
      PlacedNode(
        node: node,
        role: role,
        hop: 1,
        degree: role == GraphNodeRole.overflow ? 0 : degreeOf(node.id),
        position: polar(ring1, centers[i]),
        radius: ring1Metrics[i].radius,
        footprint: ring1Metrics[i].footprint,
        parentId: role == GraphNodeRole.overflow ? focusId : null,
        hiddenCount: role == GraphNodeRole.overflow
            ? hidden[focusId]!.length
            : 0,
      ),
    );
  }

  var flat = 0;
  for (var i = 0; i < n1; i++) {
    final parent = ring1Items[i].$1;
    for (final (node, role) in ring2Items[i]) {
      final m = childMetricsFlat[flat];
      final angle = childAngles[flat].$2;
      flat++;
      placed.add(
        PlacedNode(
          node: node,
          role: role,
          hop: 2,
          degree: role == GraphNodeRole.overflow ? 0 : degreeOf(node.id),
          position: polar(ring2, angle),
          radius: m.radius,
          footprint: m.footprint,
          parentId: parent.id,
          hiddenCount: role == GraphNodeRole.overflow
              ? hidden[parent.id]!.length
              : 0,
        ),
      );
    }
  }

  // ── 연결선 ───────────────────────────────────────────────────────

  final ids = {for (final p in placed) p.node.id};
  final links = [
    for (final l in graph.links)
      if (ids.contains(l.sourceId) && ids.contains(l.targetId)) l,
    // "+N" 묶음은 부모와 점선으로 잇는다.
    for (final p in placed)
      if (p.role == GraphNodeRole.overflow)
        ConceptLink(
          p.parentId!,
          p.node.id,
          status: ConceptLinkStatus.suggested,
        ),
  ];

  var bounds = Rect.fromCircle(
    center: Offset.zero,
    radius: focusMetrics.footprint,
  );
  for (final p in placed) {
    bounds = bounds.expandToInclude(
      Rect.fromCircle(center: p.position, radius: p.footprint),
    );
  }

  return GraphLayout(
    nodes: placed,
    links: links,
    hidden: hidden,
    ring1: ring1,
    ring2: ring2,
    bounds: bounds,
  );
}
