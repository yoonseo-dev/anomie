import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/scrap_analysis.dart';
import '../../../shared/widgets/outlined_card.dart';
import '../../../shared/widgets/source_marker.dart';

/// 분석한 원문 요약 카드 (Figma 17:23). 기사는 꽉 찬 사각형, 책은 빈 사각형 표시.
class SourceSummaryCard extends StatelessWidget {
  const SourceSummaryCard({super.key, required this.analysis});

  final ScrapAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      variant: OutlinedCardVariant.inverted,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SourceMarker(source: analysis.source, color: AppColors.white),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  analysis.origin,
                  style: AppTypography.caption.copyWith(color: AppColors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            analysis.title,
            style: AppTypography.articleTitle.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}
