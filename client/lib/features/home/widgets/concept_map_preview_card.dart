import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/concept_graph.dart';
import '../../../shared/widgets/concept_graph/concept_graph_view.dart';
import '../../../shared/widgets/legend_line.dart';
import '../../../shared/widgets/outlined_card.dart';

/// "내 개념" 마인드맵 미리보기 카드 (Figma 14:35).
class ConceptMapPreviewCard extends StatelessWidget {
  const ConceptMapPreviewCard({
    super.key,
    required this.graph,
    required this.onTap,
  });

  final ConceptGraph graph;
  final VoidCallback onTap;

  /// Figma 카드 비율 (335 × 236). 폭에 맞춰 높이가 함께 바뀐다.
  static const aspectRatio = 335 / 236;

  @override
  Widget build(BuildContext context) {
    final focus = graph.mostScrapped;

    return OutlinedCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          children: [
            if (focus != null)
              Positioned.fill(
                child: ConceptGraphPreview(
                  graph: graph,
                  focusId: focus.id,
                  style: ConceptGraphStyle.compact,
                  // 왼쪽 위 제목을 피해 가운데 개념을 오른쪽 아래로 조금 옮긴다.
                  alignment: const Alignment(0.2, 0.15),
                  padding: const EdgeInsets.fromLTRB(28, 44, 28, 28),
                  // 작은 카드에서 글자가 읽히도록 덜 줄인다. 바깥 개념은 카드 밖으로 잘려도 된다.
                  minScale: 0.85,
                ),
              ),
            Positioned(
              left: 14,
              top: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OnWhite(
                    child: Text('내 개념', style: AppTypography.sectionMedium),
                  ),
                  const SizedBox(height: 2),
                  _OnWhite(
                    child: Text(
                      '${graph.nodes.length}개 개념, '
                      '${graph.confirmedLinkCount}개 연결',
                      style: AppTypography.caption,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              right: 10,
              top: 8,
              child: ExcludeSemantics(child: Icon(Icons.north_east, size: 18)),
            ),
            if (graph.suggestedLinkCount > 0)
              Positioned(
                left: 14,
                bottom: 12,
                child: _OnWhite(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LegendLine(dashed: true, width: 14),
                      const SizedBox(width: 6),
                      Text(
                        '새 제안 ${graph.suggestedLinkCount}',
                        style: AppTypography.captionMedium,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 그래프 선 위에 글자가 겹쳐도 읽히도록 흰 바탕을 깐다.
class _OnWhite extends StatelessWidget {
  const _OnWhite({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: child,
      ),
    );
  }
}
