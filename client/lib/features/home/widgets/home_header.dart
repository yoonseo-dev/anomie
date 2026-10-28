import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/corner_marks.dart';

/// 로고·메뉴 줄 + "ANOMIE / 개념 노트" 워드마크 (Figma 14:18 ~ 14:34).
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, this.onMenuTap});

  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ContentWidth(
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/logo.svg',
                  width: 22,
                  height: 22,
                  semanticsLabel: 'Anomie',
                ),
                const Spacer(),
                IconButton(
                  onPressed: onMenuTap,
                  tooltip: '메뉴',
                  // 아이콘이 오른쪽 여백선에 맞도록 버튼 안쪽 여백을 바깥으로 민다.
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  style: const ButtonStyle(alignment: Alignment.centerRight),
                  icon: const _TwoBarMenuIcon(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const CornerMarks(),
        const SizedBox(height: AppSpacing.xs),
        Text('ANOMIE', style: AppTypography.brandLarge),
        const SizedBox(height: AppSpacing.xxs),
        Text('개념 노트', style: AppTypography.tagline),
        const SizedBox(height: AppSpacing.sm),
        const CornerMarks(),
      ],
    );
  }
}

/// Figma의 두 줄 메뉴 아이콘 (22×22 안에 18×1.5 막대 두 개).
class _TwoBarMenuIcon extends StatelessWidget {
  const _TwoBarMenuIcon();

  @override
  Widget build(BuildContext context) {
    const bar = SizedBox(
      width: 18,
      height: AppStroke.regular,
      child: ColoredBox(color: AppColors.black),
    );
    return const SizedBox.square(
      dimension: 22,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [bar, SizedBox(height: 5.5), bar],
      ),
    );
  }
}
