import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/data/page_photo_source.dart';
import '../../../shared/models/scrap_analysis.dart';
import '../../../shared/widgets/book_glyph.dart';
import '../../../shared/widgets/dashed_rrect_border.dart';
import '../../../shared/widgets/outlined_card.dart';
import '../../../shared/widgets/pill_button.dart';

/// 책 페이지 사진 카드 (Figma 16:293). 고르기 전에는 점선 카드에 촬영·앨범 버튼을 보여 준다.
class PagePhotoCard extends StatelessWidget {
  const PagePhotoCard({super.key, required this.photo, required this.onPick});

  final PagePhoto? photo;
  final ValueChanged<PhotoOrigin> onPick;

  /// Figma 카드 비율 (335 × 210).
  static const aspectRatio = 335 / 210;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
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
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  PillButton(
                    label: '페이지 촬영',
                    onPressed: () => onPick(PhotoOrigin.camera),
                    size: PillButtonSize.small,
                  ),
                  PillButton(
                    label: '앨범에서 고르기',
                    onPressed: () => onPick(PhotoOrigin.gallery),
                    variant: PillButtonVariant.outlined,
                    size: PillButtonSize.small,
                  ),
                ],
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
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Image.memory(
                  photo.bytes,
                  semanticLabel: '고른 페이지 사진',
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  // 브라우저가 못 여는 형식(HEIC 등)이어도 서버는 형식을 따로 확인한다.
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      '미리보기를 표시할 수 없어요',
                      style: AppTypography.caption,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Wrap(
                spacing: AppSpacing.xs,
                children: [
                  PillButton(
                    label: '다시 찍기',
                    onPressed: () => onPick(PhotoOrigin.camera),
                    size: PillButtonSize.small,
                  ),
                  PillButton(
                    label: '앨범',
                    onPressed: () => onPick(PhotoOrigin.gallery),
                    variant: PillButtonVariant.outlined,
                    size: PillButtonSize.small,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
