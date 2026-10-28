import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/scrap.dart';

/// 최근 스크랩 한 줄 (Figma 14:83). 기사는 꽉 찬 사각형, 책은 빈 세로 사각형으로 구분한다.
class RecentScrapTile extends StatelessWidget {
  const RecentScrapTile({super.key, required this.scrap, this.onTap});

  final Scrap scrap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isArticle = scrap.source == ScrapSource.article;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 10,
              child: Center(
                child: isArticle
                    ? const SizedBox.square(
                        dimension: 8,
                        child: ColoredBox(color: AppColors.black),
                      )
                    : Container(
                        width: 7,
                        height: 10,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.black,
                            width: 1.25,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scrap.title,
                    style: AppTypography.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    scrap.origin,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              // 태그 요약이 길어도 제목 자리를 너무 빼앗지 않게 한다.
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                scrap.conceptSummary,
                style: AppTypography.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
