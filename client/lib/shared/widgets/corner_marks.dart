import 'package:flutter/widgets.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'content_width.dart';

/// 화면 구역을 나누는 양쪽 "+" 표시. 표시의 가운데가 본문 좌우 여백선에 온다.
/// [child]를 주면 두 표시 사이 가운데에 놓인다 (마인드맵 이동 경로 등).
class CornerMarks extends StatelessWidget {
  const CornerMarks({super.key, this.child});

  final Widget? child;

  static const double _size = 11;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ContentWidth(
        padded: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter - _size / 2,
          ),
          child: Row(
            children: [
              const _Mark(),
              Expanded(child: Center(child: child)),
              const _Mark(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: CornerMarks._size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: CornerMarks._size,
            height: AppStroke.hairline,
            child: ColoredBox(color: AppColors.black),
          ),
          SizedBox(
            width: AppStroke.hairline,
            height: CornerMarks._size,
            child: ColoredBox(color: AppColors.black),
          ),
        ],
      ),
    );
  }
}
