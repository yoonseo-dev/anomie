import 'package:flutter/widgets.dart';

import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/legend_line.dart';

/// "── 연결  ---- 제안" 범례 (Figma 14:175).
class GraphLegend extends StatelessWidget {
  const GraphLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(String label, {required bool dashed}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LegendLine(dashed: dashed),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.captionMedium),
      ],
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item('연결', dashed: false),
        const SizedBox(width: 14),
        item('제안', dashed: true),
      ],
    );
  }
}
