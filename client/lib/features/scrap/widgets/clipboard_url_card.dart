import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/outlined_card.dart';
import '../../../shared/widgets/pill_button.dart';
import '../scrap_validators.dart';

/// "복사해 둔 주소" 검정 카드 (Figma 16:245).
class ClipboardUrlCard extends StatelessWidget {
  const ClipboardUrlCard({super.key, required this.url, required this.onPaste});

  final String url;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      variant: OutlinedCardVariant.inverted,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '복사해 둔 주소',
                  style: AppTypography.caption.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ScrapValidators.withoutScheme(url),
                  style: AppTypography.tab.copyWith(color: AppColors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PillButton(
            label: '붙여넣기',
            onPressed: onPaste,
            variant: PillButtonVariant.outlined,
            size: PillButtonSize.small,
          ),
        ],
      ),
    );
  }
}
