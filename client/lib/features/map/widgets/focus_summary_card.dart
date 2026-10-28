import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/concept_graph.dart';
import '../../../shared/widgets/pill_button.dart';

/// 마인드맵 가운데 개념 요약 + "자세히" (Figma 14:169).
class FocusSummaryCard extends StatelessWidget {
  const FocusSummaryCard({
    super.key,
    required this.graph,
    required this.concept,
    required this.onDetail,
  });

  final ConceptGraph graph;
  final ConceptNode concept;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final links = graph.linksOf(concept.id).toList();
    final suggested = links.where((l) => l.isSuggested).length;
    final confirmed = links.length - suggested;
    const white = AppColors.white;

    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: AppColors.black,
        shape: StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    concept.name,
                    style: AppTypography.section.copyWith(color: white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '스크랩 ${concept.scrapCount}  연결 $confirmed  '
                    '제안 $suggested',
                    style: AppTypography.caption.copyWith(color: white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PillButton(
              label: '자세히',
              onPressed: onDetail,
              variant: PillButtonVariant.inverted,
              size: PillButtonSize.medium,
            ),
          ],
        ),
      ),
    );
  }
}
