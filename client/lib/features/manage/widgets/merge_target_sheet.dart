import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/concept_graph.dart';

/// 병합할 대상 개념을 고르는 시트. 고른 개념을 돌려주며 닫힌다.
abstract final class MergeTargetSheet {
  static Future<ConceptNode?> show(
    BuildContext context, {
    required ConceptNode from,
    required List<ConceptNode> candidates,
  }) {
    final sorted = [...candidates]..sort((a, b) => a.name.compareTo(b.name));

    return showModalBottomSheet<ConceptNode>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        maxWidth: AppSpacing.maxContentWidth,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${from.name} 병합하기', style: AppTypography.section),
                  const SizedBox(height: AppSpacing.xxs),
                  Text('합칠 태그를 골라 주세요', style: AppTypography.caption),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, i) => InkWell(
                  onTap: () => Navigator.of(context).pop(sorted[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                      vertical: AppSpacing.md,
                    ),
                    child: Text(
                      sorted[i].name,
                      style: AppTypography.bodyStrong,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
