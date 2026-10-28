import 'package:flutter/widgets.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'dashed_rrect_border.dart';

/// 범례에 쓰는 짧은 가로선. 실선은 확정된 연결, 점선은 제안을 뜻한다.
class LegendLine extends StatelessWidget {
  const LegendLine({super.key, this.dashed = false, this.width = 16});

  final bool dashed;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: AppStroke.hairline,
      child: CustomPaint(painter: _LegendLinePainter(dashed: dashed)),
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  const _LegendLinePainter({required this.dashed});

  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(size.width, y);
    final paint = Paint()
      ..color = AppColors.black
      ..strokeWidth = AppStroke.hairline
      ..style = PaintingStyle.stroke;

    if (dashed) {
      drawDashedPath(canvas, path, paint, dash: 3, gap: 2);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_LegendLinePainter old) => old.dashed != dashed;
}
