import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/scrap_analysis.dart';
import '../../../shared/widgets/book_glyph.dart';
import '../../../shared/widgets/dashed_rrect_border.dart';
import '../../../shared/widgets/outlined_card.dart';
import '../../../shared/widgets/pill_button.dart';

/// 책 페이지 사진 카드 (Figma 16:293). 촬영 전에는 점선 카드에 촬영 버튼을 보여 준다.
class PagePhotoCard extends StatelessWidget {
  const PagePhotoCard({
    super.key,
    required this.photo,
    required this.onCapture,
  });

  final PagePhoto? photo;
  final VoidCallback onCapture;

  /// Figma 카드 비율 (335 × 210).
  static const aspectRatio = 335 / 210;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return DashedRRectBorder(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BookGlyph(),
              const SizedBox(height: AppSpacing.xs),
              Text('스크랩할 페이지를 찍어 주세요', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.sm),
              PillButton(
                label: '페이지 촬영',
                onPressed: onCapture,
                size: PillButtonSize.small,
              ),
            ],
          ),
        ),
      );
    }

    return OutlinedCard(
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          children: [
            // TODO: 실제 카메라를 붙이면 photo.path의 사진을 보여 준다.
            Positioned.fill(
              child: Semantics(
                label: '촬영한 페이지',
                image: true,
                child: const _FakePagePreview(),
              ),
            ),
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: PillButton(
                label: '다시 찍기',
                onPressed: onCapture,
                size: PillButtonSize.small,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가짜 사진: 글줄과 분석할 구절을 감싼 점선 상자 (Figma 16:294 ~ 16:302).
/// 모든 위치는 카드 크기에 대한 비율이라 폭이 달라져도 같은 모양이다.
class _FakePagePreview extends StatelessWidget {
  const _FakePagePreview();

  static const _w = 335.0;
  static const _h = 210.0;

  /// (위쪽 위치, 줄 길이) — Figma 값.
  static const _lines = [
    (35.0, 240.0),
    (53.0, 240.0),
    (71.0, 200.0),
    (89.0, 240.0),
    (107.0, 240.0),
    (125.0, 200.0),
    (143.0, 240.0),
    (161.0, 110.0),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final sx = c.maxWidth / _w;
        final sy = c.maxHeight / _h;
        return Stack(
          children: [
            for (final (top, width) in _lines)
              Positioned(
                left: 45 * sx,
                top: top * sy,
                width: width * sx,
                height: AppStroke.hairline,
                child: const ColoredBox(color: AppColors.black),
              ),
            Positioned(
              left: 37 * sx,
              top: 59 * sy,
              width: 256 * sx,
              height: 24 * sy,
              child: const DashedRRectBorder(
                radius: 6,
                child: SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }
}
