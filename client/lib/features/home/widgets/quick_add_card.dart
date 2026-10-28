import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/scrap.dart';
import '../../../shared/widgets/book_glyph.dart';
import '../../../shared/widgets/outlined_card.dart';

/// 홈의 "기사 / 책" 스크랩 추가 카드 (Figma 14:67, 14:74).
class QuickAddCard extends StatelessWidget {
  const QuickAddCard({super.key, required this.source, required this.onTap});

  final ScrapSource source;
  final VoidCallback onTap;

  bool get _isArticle => source == ScrapSource.article;

  @override
  Widget build(BuildContext context) {
    final fg = _isArticle ? AppColors.white : AppColors.black;
    final title = _isArticle ? '기사' : '책';

    return Semantics(
      button: true,
      label: '$title 스크랩 추가',
      excludeSemantics: true,
      child: OutlinedCard(
        variant: _isArticle
            ? OutlinedCardVariant.inverted
            : OutlinedCardVariant.solid,
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.title.copyWith(color: fg)),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _isArticle ? 'URL 붙여넣기' : '페이지 촬영',
              style: AppTypography.caption.copyWith(color: fg),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.add, size: 22, color: fg),
                const Spacer(),
                _isArticle ? const _LinkGlyph() : const BookGlyph(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 비스듬히 겹친 두 고리 (Figma 14:70). 검정 카드 위에 놓인다.
class _LinkGlyph extends StatelessWidget {
  const _LinkGlyph();

  static Widget _ring(Offset center) => Positioned(
    left: center.dx - 10,
    top: center.dy - 5,
    child: Transform.rotate(
      angle: -35 * math.pi / 180,
      child: Container(
        width: 20,
        height: 10,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.white, width: AppStroke.regular),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: Stack(
        children: [
          _ring(const Offset(15, 18.4)),
          _ring(const Offset(27, 26.4)),
        ],
      ),
    );
  }
}
