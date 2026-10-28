import 'package:flutter/widgets.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// "찾은 개념 3", "내 스크랩에서 3"처럼 제목 옆에 개수가 붙는 섹션 제목.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.large = false,
  });

  final String title;

  /// 제목 옆 보조 글자 ("3", "2 + 제안 1").
  final String? count;

  /// true면 18px 제목 + 14px 개수 (태그 확인), false면 16px + 13px (상세 화면).
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            title,
            style: large
                ? AppTypography.sectionLarge
                : AppTypography.sectionMedium,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            count!,
            style: large ? AppTypography.body : AppTypography.sectionCount,
          ),
        ],
      ],
    );
  }
}
