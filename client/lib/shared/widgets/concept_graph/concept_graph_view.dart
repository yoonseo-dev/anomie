import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../models/concept_graph.dart';
import 'concept_graph_painter.dart';
import 'radial_layout.dart';

/// 그래프 크기·글자·상한 설정.
class ConceptGraphStyle {
  const ConceptGraphStyle({
    required this.focusDiameter,
    required this.circleDiameter,
    required this.pointDiameter,
    required this.overflowDiameter,
    required this.focusLabel,
    required this.circleLabel,
    required this.pointLabel,
    required this.overflowLabel,
    required this.maxPrimary,
    required this.maxChildrenPerNode,
    required this.minEdge,
    required this.gap,
    required this.orbits,
    this.focusRingGap,
    this.showOverflow = true,
  });

  final double focusDiameter;

  /// 스크랩 수에 따라 이 범위 안에서 크기를 정한다. 이름이 길면 더 커진다.
  final (double, double) circleDiameter;

  /// 연결 수에 따라 이 범위 안에서 크기를 정한다.
  final (double, double) pointDiameter;

  final double overflowDiameter;

  final TextStyle focusLabel;
  final TextStyle circleLabel;
  final TextStyle pointLabel;
  final TextStyle overflowLabel;

  /// 1단계 개념 상한 ("+N" 묶음 포함).
  final int maxPrimary;

  /// 부모 하나당 2단계 개념 상한 ("+N" 묶음 포함).
  final int maxChildrenPerNode;

  /// 원 테두리 사이 최소 선 길이.
  final double minEdge;

  /// 이웃한 개념 사이 최소 간격.
  final double gap;

  /// 배경 점선 동심원 반지름.
  final List<double> Function(GraphLayout layout) orbits;

  final double? focusRingGap;

  /// false면 상한을 넘는 개념을 "+N" 묶음 없이 그냥 숨긴다 (작은 미리보기).
  final bool showOverflow;

  /// 홈 카드 안의 작은 미리보기 (Figma 14:35).
  static final compact = ConceptGraphStyle(
    focusDiameter: 64,
    circleDiameter: (36, 52),
    pointDiameter: (8, 12),
    overflowDiameter: 30,
    focusLabel: AppTypography.graphFocusSmall.copyWith(color: AppColors.white),
    circleLabel: AppTypography.graphNodeSmall,
    pointLabel: AppTypography.graphPointSmall,
    overflowLabel: AppTypography.graphNodeSmall,
    maxPrimary: 6,
    maxChildrenPerNode: 1,
    minEdge: 14,
    gap: 6,
    orbits: (l) => [l.ring1, if (l.ring2 > l.ring1) l.ring2],
    showOverflow: false,
  );

  /// 마인드맵 화면 (Figma 14:110).
  static final full = ConceptGraphStyle(
    focusDiameter: 118,
    focusRingGap: 7,
    circleDiameter: (54, 88),
    pointDiameter: (8, 16),
    overflowDiameter: 44,
    focusLabel: AppTypography.graphFocus.copyWith(color: AppColors.white),
    circleLabel: AppTypography.graphNode,
    pointLabel: AppTypography.graphPoint,
    overflowLabel: AppTypography.graphNode,
    maxPrimary: 6,
    maxChildrenPerNode: 2,
    minEdge: 28,
    gap: 10,
    orbits: (l) => [
      l.ring1 * 0.72,
      l.ring2,
      l.ring2 + math.max(l.ring2 - l.ring1, 80),
    ],
  );

  static double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// 원 안 이름은 띄어쓰기마다 줄을 바꾼다 ("상대적\n박탈감").
  static String circleText(String name) => name.replaceAll(' ', '\n');

  NodeMetrics measure(
    ConceptNode node,
    GraphNodeRole role,
    int degree,
    int maxScrap,
  ) {
    switch (role) {
      case GraphNodeRole.focus:
        final d = math.max(
          focusDiameter,
          _textWidth(node.name, focusLabel) + 24,
        );
        return (radius: d / 2, footprint: d / 2 + (focusRingGap ?? 0));
      case GraphNodeRole.circle:
        final t = maxScrap <= 1 ? 0.0 : (node.scrapCount - 1) / (maxScrap - 1);
        final base = lerpDouble(circleDiameter.$1, circleDiameter.$2, t)!;
        // 이름이 원 밖으로 넘치지 않게 가장 긴 줄보다 크게 한다.
        final d = math.max(
          base,
          _textWidth(circleText(node.name), circleLabel) + 16,
        );
        return (radius: d / 2, footprint: d / 2);
      case GraphNodeRole.point:
        final t = ((degree - 1) / 2).clamp(0.0, 1.0);
        final d = lerpDouble(pointDiameter.$1, pointDiameter.$2, t)!;
        // 이름표가 점 옆으로 붙으므로 이름표 폭만큼 자리를 더 잡는다.
        final label = _textWidth(node.name, pointLabel) + 6;
        return (radius: d / 2, footprint: d / 2 + 2 + label);
      case GraphNodeRole.overflow:
        return (radius: overflowDiameter / 2, footprint: overflowDiameter / 2);
    }
  }

  GraphLayout layoutFor(ConceptGraph graph, String focusId) => radialLayout(
    graph,
    focusId,
    measure: measure,
    maxPrimary: maxPrimary,
    maxChildrenPerNode: maxChildrenPerNode,
    minEdge: minEdge,
    gap: gap,
    showOverflow: showOverflow,
  );
}

/// 가운데 개념과 1단계 고리까지가 차지하는 반지름. 처음 보여 줄 확대 정도를 정할 때 쓴다.
double primaryExtent(GraphLayout layout) => layout.nodes
    .where((n) => n.hop <= 1)
    .fold<double>(0, (m, n) => math.max(m, n.position.distance + n.footprint));

/// 배치된 그래프를 실제 크기로 그리는 캔버스. 크기는 배치 범위에 맞춰 정해진다.
class ConceptGraphCanvas extends StatelessWidget {
  const ConceptGraphCanvas({
    super.key,
    required this.layout,
    required this.style,
    this.onNodeTap,
    this.onOverflowTap,
  });

  final GraphLayout layout;
  final ConceptGraphStyle style;

  /// null이면 개념을 눌러도 반응하지 않는다 (미리보기).
  final ValueChanged<String>? onNodeTap;

  /// "+N" 묶음을 눌렀을 때. 인자는 묶음의 부모 id.
  final ValueChanged<String>? onOverflowTap;

  static const double margin = 16;

  Rect get _area => layout.bounds.inflate(margin);

  /// 캔버스 크기.
  Size get size => _area.size;

  /// 캔버스 안에서 가운데 개념이 놓이는 위치.
  Offset get origin => -_area.topLeft;

  String get _focusId => layout.nodes.first.node.id;

  VoidCallback? _tapFor(PlacedNode n) {
    if (n.role == GraphNodeRole.overflow) {
      return onOverflowTap == null ? null : () => onOverflowTap!(n.parentId!);
    }
    if (onNodeTap == null || n.node.id == _focusId) return null;
    return () => onNodeTap!(n.node.id);
  }

  @override
  Widget build(BuildContext context) {
    if (layout.nodes.isEmpty) return const SizedBox.shrink();

    Widget canvas = SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: ConceptGraphPainter(
                layout: layout,
                origin: origin,
                orbitRadii: style.orbits(layout),
                focusRingGap: style.focusRingGap,
              ),
            ),
          ),
          for (final n in layout.nodes) _label(n),
        ],
      ),
    );

    if (onNodeTap != null || onOverflowTap != null) {
      canvas = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _hitTest(details.localPosition)?.call(),
        child: canvas,
      );
    }

    return Semantics(
      container: true,
      label:
          '${layout.nodes.first.node.name} 중심 개념 지도, '
          '개념 ${layout.nodes.length}개',
      child: canvas,
    );
  }

  /// 화면 낭독기에서도 개념을 하나씩 골라 누를 수 있게 하고,
  /// 점에서 떨어진 이름표를 눌러도 선택되게 한다.
  Widget _tappable(PlacedNode n, Widget child) {
    final onTap = _tapFor(n);
    final label = n.role == GraphNodeRole.overflow
        ? '숨은 개념 ${n.hiddenCount}개 보기'
        : n.node.name;
    return Semantics(
      button: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: onTap == null
          ? child
          : GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: child,
            ),
    );
  }

  Widget _label(PlacedNode n) {
    final c = origin + n.position;

    if (n.role != GraphNodeRole.point) {
      final (text, textStyle) = switch (n.role) {
        GraphNodeRole.focus => (n.node.name, style.focusLabel),
        GraphNodeRole.overflow => (n.node.name, style.overflowLabel),
        _ => (ConceptGraphStyle.circleText(n.node.name), style.circleLabel),
      };
      return Positioned.fromRect(
        rect: Rect.fromCircle(center: c, radius: n.radius),
        child: _tappable(
          n,
          Center(
            child: Text(text, textAlign: TextAlign.center, style: textStyle),
          ),
        ),
      );
    }

    // 점 이름표는 바깥쪽(가운데에서 먼 쪽)에 붙인다. 흰 바탕이 연결선을 가린다.
    final gap = n.radius + 2;
    final label = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: Text(n.node.name, style: style.pointLabel, maxLines: 1),
      ),
    );

    return Positioned(
      left: n.labelOnRight ? c.dx + gap : null,
      right: n.labelOnRight ? null : size.width - c.dx + gap,
      top: c.dy,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: _tappable(n, label),
      ),
    );
  }

  VoidCallback? _hitTest(Offset position) {
    // 작은 점도 누르기 쉽도록 최소 반경 22를 준다. 위에 그려진 것부터 확인한다.
    for (final n in layout.nodes.reversed) {
      final c = origin + n.position;
      if ((c - position).distance <= math.max(n.radius, 22)) return _tapFor(n);
    }
    return null;
  }
}

/// 홈 카드처럼 고정된 상자 안에 그래프를 보여 주는 미리보기. 누를 수 없다.
///
/// 가운데 개념을 [alignment] 자리에 두고, 1단계 고리가 상자 안에 들어오도록
/// 축소한다. 2단계 개념은 상자 밖으로 잘릴 수 있다.
class ConceptGraphPreview extends StatelessWidget {
  const ConceptGraphPreview({
    super.key,
    required this.graph,
    required this.focusId,
    required this.style,
    this.alignment = Alignment.center,
    this.padding = EdgeInsets.zero,
    this.minScale = 0.6,
  });

  final ConceptGraph graph;
  final String focusId;
  final ConceptGraphStyle style;
  final Alignment alignment;
  final EdgeInsets padding;
  final double minScale;

  @override
  Widget build(BuildContext context) {
    final layout = style.layoutFor(graph, focusId);
    final canvas = ConceptGraphCanvas(layout: layout, style: style);

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = padding.deflateRect(Offset.zero & constraints.biggest);
        final anchor = alignment.withinRect(area);
        final extent = math.max(primaryExtent(layout), 1.0);
        final scale = (area.shortestSide / (2 * extent)).clamp(minScale, 1.0);

        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: anchor.dx - canvas.origin.dx * scale,
                top: anchor.dy - canvas.origin.dy * scale,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: canvas,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 마인드맵을 처음 열거나 가운데 개념이 바뀌었을 때의 확대·이동 값.
/// 1단계 고리가 [visible] 안에 들어오도록 축소하고 가운데 개념을 그 중심에 둔다.
Matrix4 fitGraphTransform({
  required GraphLayout layout,
  required Offset origin,
  required Rect visible,
  double minScale = 0.5,
  double maxScale = 1,
}) {
  final extent = math.max(primaryExtent(layout), 1.0);
  final scale = (visible.shortestSide / (2 * extent)).clamp(minScale, maxScale);
  final t = visible.center - origin * scale;
  return Matrix4.translationValues(t.dx, t.dy, 0)
    ..multiply(Matrix4.diagonal3Values(scale, scale, 1));
}
