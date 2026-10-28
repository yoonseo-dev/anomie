import 'package:flutter/rendering.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../models/concept_graph.dart';
import '../dashed_rrect_border.dart';
import 'radial_layout.dart';

/// 동심원, 연결선, 개념 원·점을 그린다. 이름표는 위젯으로 따로 얹는다.
///
/// [origin]은 캔버스 안에서 가운데 개념이 놓이는 위치다.
class ConceptGraphPainter extends CustomPainter {
  const ConceptGraphPainter({
    required this.layout,
    required this.origin,
    required this.orbitRadii,
    this.focusRingGap,
    this.curveBend = 0.12,
  });

  final GraphLayout layout;
  final Offset origin;
  final List<double> orbitRadii;

  /// 지정하면 가운데 원 바깥에 이만큼 떨어진 고리를 하나 더 그린다.
  final double? focusRingGap;

  /// 연결선이 휘는 정도 (선 길이 대비).
  final double curveBend;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.black
      ..strokeWidth = AppStroke.hairline
      ..style = PaintingStyle.stroke;

    for (final r in orbitRadii) {
      drawDashedPath(
        canvas,
        Path()..addOval(Rect.fromCircle(center: origin, radius: r)),
        stroke,
      );
    }

    final byId = {for (final n in layout.nodes) n.node.id: n};
    for (final ConceptLink link in layout.links) {
      final a = byId[link.sourceId];
      final b = byId[link.targetId];
      if (a == null || b == null) continue;

      final path = _curve(origin + a.position, origin + b.position);
      if (link.isSuggested) {
        drawDashedPath(canvas, path, stroke);
      } else {
        canvas.drawPath(path, stroke);
      }
    }

    final fill = Paint()..style = PaintingStyle.fill;
    for (final n in layout.nodes) {
      final c = origin + n.position;
      switch (n.role) {
        case GraphNodeRole.focus:
          canvas.drawCircle(c, n.radius, fill..color = AppColors.black);
          if (focusRingGap != null) {
            canvas.drawCircle(c, n.radius + focusRingGap!, stroke);
          }
        case GraphNodeRole.circle:
          canvas.drawCircle(c, n.radius, fill..color = AppColors.white);
          canvas.drawCircle(c, n.radius, stroke);
        case GraphNodeRole.point:
          canvas.drawCircle(c, n.radius, fill..color = AppColors.black);
        case GraphNodeRole.overflow:
          canvas.drawCircle(c, n.radius, fill..color = AppColors.white);
          drawDashedPath(
            canvas,
            Path()..addOval(Rect.fromCircle(center: c, radius: n.radius)),
            stroke,
          );
      }
    }
  }

  /// 두 점을 잇는 살짝 휜 곡선.
  Path _curve(Offset a, Offset b) {
    final mid = (a + b) / 2;
    final d = b - a;
    final normal = Offset(-d.dy, d.dx);
    final control = mid + normal * curveBend;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);
  }

  @override
  bool shouldRepaint(ConceptGraphPainter old) =>
      old.layout != layout ||
      old.origin != origin ||
      old.orbitRadii != orbitRadii ||
      old.focusRingGap != focusRingGap ||
      old.curveBend != curveBend;
}
