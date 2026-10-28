import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import 'legend_line.dart';

/// "아노미 ── 상대적 박탈감"처럼 두 개념을 잇는 한 줄.
/// 제안은 점선, 확정된 연결은 실선으로 잇는다.
class ConceptPair extends StatelessWidget {
  const ConceptPair({
    super.key,
    required this.left,
    required this.right,
    this.suggested = false,
    this.onTapLeft,
    this.onTapRight,
  });

  final String left;
  final String right;
  final bool suggested;
  final VoidCallback? onTapLeft;
  final VoidCallback? onTapRight;

  @override
  Widget build(BuildContext context) {
    // 제안 카드는 굵게(SemiBold), 연결 목록은 보통(Medium)으로 쓴다 (Figma 18:119, 18:146).
    final style = suggested
        ? AppTypography.bodyEmphasis
        : AppTypography.bodyStrong;

    Widget name(String text, VoidCallback? onTap) {
      final label = Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      return Flexible(
        child: onTap == null
            ? label
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: label,
              ),
      );
    }

    return Semantics(
      label: '$left ${suggested ? '제안' : '연결'} $right',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          name(left, onTapLeft),
          const SizedBox(width: 10),
          ExcludeSemantics(
            child: LegendLine(dashed: suggested, width: suggested ? 26 : 22),
          ),
          const SizedBox(width: 10),
          name(right, onTapRight),
        ],
      ),
    );
  }
}
