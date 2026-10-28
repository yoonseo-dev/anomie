import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/outlined_card.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../../shared/widgets/text_link_button.dart';
import '../tag_review_controller.dart';

/// 찾은 개념 하나 (Figma 17:32 내 태그 / 17:50 새 태그).
class SuggestedTagCard extends StatelessWidget {
  const SuggestedTagCard({
    super.key,
    required this.draft,
    required this.onReplace,
    required this.onRename,
    required this.onRemove,
  });

  final TagDraft draft;

  /// "비슷한 내 태그로 바꾸기"에서 칩을 눌렀을 때.
  final ValueChanged<String> onReplace;

  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isNew = draft.showsAsNew;
    final similar = draft.isNew ? draft.suggestion.similarExisting : const [];

    return OutlinedCard(
      variant: isNew ? OutlinedCardVariant.dashed : OutlinedCardVariant.solid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TagChip(
                    label: draft.finalName,
                    variant: isNew
                        ? TagChipVariant.suggested
                        : TagChipVariant.confirmed,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(isNew ? '새 태그' : '내 태그', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(draft.suggestion.reason, style: AppTypography.bodySmall),
          if (similar.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('비슷한 내 태그로 바꾸기', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in similar)
                  TagChip(
                    label: name,
                    variant: draft.replacedWith == name
                        ? TagChipVariant.selected
                        : TagChipVariant.confirmed,
                    onTap: () => onReplace(name),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            children: [
              TextLinkButton(label: '이름 수정하기', onPressed: onRename),
              TextLinkButton(label: '빼기', onPressed: onRemove),
            ],
          ),
        ],
      ),
    );
  }
}
