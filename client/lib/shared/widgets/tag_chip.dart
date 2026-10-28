import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import 'dashed_rrect_border.dart';

enum TagChipVariant {
  /// 확정된 내 태그: 실선 테두리.
  confirmed,

  /// AI가 제안한 새 태그 / 승인 전 연결: 점선 테두리.
  suggested,

  /// 선택됨: 검정 채움.
  selected,
}

enum TagChipSize {
  /// 태그 (12 Medium, 여백 12×7).
  regular,

  /// 정렬·필터 칩 (11 Medium, 여백 12×6: "스크랩 많은 순").
  small,
}

/// 사회학 개념 태그 칩. 정렬·필터 칩으로도 쓴다.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.variant = TagChipVariant.confirmed,
    this.onTap,
    this.onDelete,
    this.size = TagChipSize.regular,
  });

  final String label;
  final TagChipVariant variant;
  final VoidCallback? onTap;

  /// 지정하면 오른쪽에 지우기(×) 버튼이 생긴다.
  final VoidCallback? onDelete;

  final TagChipSize size;

  bool get _isSelected => variant == TagChipVariant.selected;

  bool get _isSmall => size == TagChipSize.small;

  @override
  Widget build(BuildContext context) {
    final fg = _isSelected ? AppColors.white : AppColors.black;
    final bg = _isSelected ? AppColors.black : AppColors.white;
    const shape = StadiumBorder();

    Widget chip = Material(
      color: bg,
      shape: variant == TagChipVariant.confirmed
          ? const StadiumBorder(side: BorderSide(color: AppColors.black))
          : shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        overlayColor: WidgetStatePropertyAll(
          _isSelected ? AppColors.pressedOnBlack : AppColors.pressedOnWhite,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: onDelete == null ? 12 : 6,
            top: _isSmall ? 6 : 7,
            bottom: _isSmall ? 6 : 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style:
                      (_isSmall
                              ? AppTypography.captionMedium
                              : AppTypography.chip)
                          .copyWith(color: fg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: AppSpacing.xxs),
                Semantics(
                  button: true,
                  label: '$label 지우기',
                  child: GestureDetector(
                    onTap: onDelete,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(Icons.close, size: 14, color: fg),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (variant == TagChipVariant.suggested) {
      chip = DashedRRectBorder(radius: AppRadius.pill, child: chip);
    }

    return chip;
  }
}
