import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// 둥근 사각형 점선 테두리. AI 제안 칩·카드처럼 "아직 확정되지 않은 것"을 나타낸다.
/// [radius]가 높이의 절반보다 크면 알약 모양이 된다.
class DashedRRectBorder extends StatelessWidget {
  const DashedRRectBorder({
    super.key,
    required this.child,
    this.radius = AppRadius.card,
    this.color = AppColors.black,
    this.strokeWidth = AppStroke.hairline,
    this.dash = AppStroke.dash,
    this.gap = AppStroke.dashGap,
  });

  final Widget child;
  final double radius;
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: DashedRRectPainter(
        radius: radius,
        color: color,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

/// [path]를 [dash] 길이 선과 [gap] 길이 빈칸으로 나눠 그린다.
void drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint, {
  double dash = AppStroke.dash,
  double gap = AppStroke.dashGap,
}) {
  for (final PathMetric metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
      distance += dash + gap;
    }
  }
}

class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final double radius;
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final r = radius.clamp(0, rect.shortestSide / 2).toDouble();
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    drawDashedPath(canvas, path, paint, dash: dash, gap: gap);
  }

  @override
  bool shouldRepaint(DashedRRectPainter old) =>
      old.radius != radius ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}
