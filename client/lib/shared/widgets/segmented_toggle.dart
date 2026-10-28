import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

class SegmentedToggleItem<T> {
  const SegmentedToggleItem({
    required this.value,
    required this.label,
    this.count,
  });

  final T value;
  final String label;

  /// 라벨 옆에 작게 붙는 숫자 ("태그 15").
  final int? count;
}

/// 둥근 2칸(이상) 전환 버튼. 기사/책, 태그/관계 전환에 쓴다.
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final List<SegmentedToggleItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: const ShapeDecoration(
        color: AppColors.white,
        shape: StadiumBorder(side: BorderSide(color: AppColors.black)),
      ),
      child: Row(
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: _Segment(item: item, toggle: this),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({required this.item, required this.toggle});

  final SegmentedToggleItem<T> item;
  final SegmentedToggle<T> toggle;

  @override
  Widget build(BuildContext context) {
    final isSelected = item.value == toggle.selected;
    final fg = isSelected ? AppColors.white : AppColors.black;
    final labelStyle =
        (isSelected ? AppTypography.buttonSmall : AppTypography.chip).copyWith(
          color: fg,
        );

    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? AppColors.black : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isSelected ? null : () => toggle.onChanged(item.value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text.rich(
              TextSpan(
                text: item.label,
                children: [
                  if (item.count != null)
                    TextSpan(
                      text: '  ${item.count}',
                      style: AppTypography.caption.copyWith(color: fg),
                    ),
                ],
              ),
              style: labelStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
