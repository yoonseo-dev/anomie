import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/concept_detail.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../../shared/widgets/text_link_button.dart';

/// "연결된 개념" 한 줄 (Figma 18:79). 확정은 실선 칩 + "연결됨",
/// 제안은 점선 칩 + "제안 확인하기".
class LinkedConceptRow extends StatelessWidget {
  const LinkedConceptRow({
    super.key,
    required this.linked,
    required this.onOpen,
    required this.onReviewSuggestion,
  });

  final LinkedConcept linked;

  /// 칩을 눌러 그 개념의 상세로 갈 때.
  final VoidCallback onOpen;

  final VoidCallback onReviewSuggestion;

  @override
  Widget build(BuildContext context) {
    final suggested = linked.link.isSuggested;
    final reason = linked.link.reason;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.black)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TagChip(
                      label: linked.concept.name,
                      variant: suggested
                          ? TagChipVariant.suggested
                          : TagChipVariant.confirmed,
                      onTap: onOpen,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                suggested
                    ? TextLinkButton(
                        label: '제안 확인하기',
                        small: true,
                        onPressed: onReviewSuggestion,
                      )
                    : Text('연결됨', style: AppTypography.caption),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(reason, style: AppTypography.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
