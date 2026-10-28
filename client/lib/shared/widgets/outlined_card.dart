import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'dashed_rrect_border.dart';

enum OutlinedCardVariant {
  /// 흰 바탕 + 실선 테두리 (확정된 내용).
  solid,

  /// 흰 바탕 + 점선 테두리 (AI 제안, 승인 전).
  dashed,

  /// 검정 바탕 (강조 카드). 안의 글자는 흰색으로 써야 한다.
  inverted,
}

/// 모서리 20 공통 카드.
class OutlinedCard extends StatelessWidget {
  const OutlinedCard({
    super.key,
    required this.child,
    this.variant = OutlinedCardVariant.solid,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  final Widget child;
  final OutlinedCardVariant variant;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    final isInverted = variant == OutlinedCardVariant.inverted;

    Widget card = Material(
      color: isInverted ? AppColors.black : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: variant == OutlinedCardVariant.solid
            ? const BorderSide(color: AppColors.black)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStatePropertyAll(
          isInverted ? AppColors.pressedOnBlack : AppColors.pressedOnWhite,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (variant == OutlinedCardVariant.dashed) {
      card = DashedRRectBorder(radius: AppRadius.card, child: card);
    }

    return card;
  }
}
