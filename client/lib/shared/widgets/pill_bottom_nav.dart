import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// 화면 아래에 떠 있는 둥근 하단 메뉴 (홈 / 마인드맵 / 관리).
/// 위치는 정하지 않는다. 배치는 쓰는 쪽(AppShell)이 맡는다.
class PillBottomNav extends StatelessWidget {
  const PillBottomNav({
    super.key,
    required this.labels,
    required this.currentIndex,
    required this.onTap,
  });

  final List<String> labels;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: const ShapeDecoration(
        color: AppColors.white,
        shape: StadiumBorder(side: BorderSide(color: AppColors.black)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, label) in labels.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            _NavItem(
              label: label,
              selected: i == currentIndex,
              onTap: () => onTap(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = selected
        ? AppTypography.tabSelected.copyWith(color: AppColors.white)
        : AppTypography.tab;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.black : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // 선택된 칸이 Figma에서 조금 더 넓다 (22 vs 18).
            padding: EdgeInsets.symmetric(
              horizontal: selected ? 22 : 18,
              vertical: 11,
            ),
            child: Text(label, style: style),
          ),
        ),
      ),
    );
  }
}
