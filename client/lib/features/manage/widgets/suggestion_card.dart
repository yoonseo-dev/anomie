import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/concept_pair.dart';
import '../../../shared/widgets/outlined_card.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/text_link_button.dart';

/// "확인 기다리는 제안" 카드 (Figma 18:117). 점선 카드 + 승인/거절/수정하기.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    super.key,
    required this.left,
    required this.right,
    required this.reason,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    this.onTapLeft,
    this.onTapRight,
  });

  final String left;
  final String right;
  final String? reason;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback? onTapLeft;
  final VoidCallback? onTapRight;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      variant: OutlinedCardVariant.dashed,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConceptPair(
            left: left,
            right: right,
            suggested: true,
            onTapLeft: onTapLeft,
            onTapRight: onTapRight,
          ),
          if (reason != null) ...[
            const SizedBox(height: 10),
            Text(reason!, style: AppTypography.bodySmall),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PillButton(
                label: '승인',
                onPressed: onApprove,
                size: PillButtonSize.small,
              ),
              PillButton(
                label: '거절',
                onPressed: onReject,
                variant: PillButtonVariant.outlined,
                size: PillButtonSize.small,
              ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xxs),
                child: TextLinkButton(label: '수정하기', onPressed: onEdit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
