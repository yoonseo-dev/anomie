import 'package:flutter/widgets.dart';

import '../../core/theme/app_dimens.dart';

/// 본문을 좌우 여백 [AppSpacing.gutter]로 감싸고, 넓은 화면에서는
/// [AppSpacing.maxContentWidth]까지만 넓힌 뒤 가운데 정렬한다.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.padded = true});

  final Widget child;

  /// false이면 좌우 여백 없이 폭 제한만 건다 (가로 스크롤 목록 등).
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: padded
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                child: child,
              )
            : child,
      ),
    );
  }
}
