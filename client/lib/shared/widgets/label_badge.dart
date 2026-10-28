import 'package:flutter/widgets.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// 작은 테두리 배지 ("AI 생성", "직접 씀"). 누를 수 없는 표시용이다.
class LabelBadge extends StatelessWidget {
  const LabelBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: AppColors.black)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(label, style: AppTypography.micro),
      ),
    );
  }
}
