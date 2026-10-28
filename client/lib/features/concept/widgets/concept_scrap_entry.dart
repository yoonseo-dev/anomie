import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/scrap.dart';
import '../../../shared/widgets/source_marker.dart';

/// "내 스크랩에서" 한 항목 (Figma 18:54). 위 구분선 + 출처 + 제목 + 이 개념을 붙인 이유.
class ConceptScrapEntry extends StatelessWidget {
  const ConceptScrapEntry({
    super.key,
    required this.scrap,
    required this.conceptName,
    this.onTap,
  });

  final Scrap scrap;
  final String conceptName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final explanation = scrap.explanations[conceptName];

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.black)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SourceMarker(source: scrap.source),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      scrap.originDetail,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(scrap.title, style: AppTypography.articleTitle),
              if (explanation != null) ...[
                const SizedBox(height: AppSpacing.xs),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: AppColors.black)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: Text(explanation, style: AppTypography.bodySmall),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
