import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/concept_pair.dart';

/// "연결됨" 한 줄 (Figma 18:144). 위 구분선 + "A ── B" + 더 보기(···).
class RelationRow extends StatelessWidget {
  const RelationRow({
    super.key,
    required this.left,
    required this.right,
    required this.onMore,
    this.onTapLeft,
    this.onTapRight,
  });

  final String left;
  final String right;
  final VoidCallback onMore;
  final VoidCallback? onTapLeft;
  final VoidCallback? onTapRight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.black)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConceptPair(
                  left: left,
                  right: right,
                  onTapLeft: onTapLeft,
                  onTapRight: onTapRight,
                ),
              ),
            ),
            IconButton(
              tooltip: '$left ── $right 메뉴',
              onPressed: onMore,
              // 오른쪽 여백선에 맞춘다.
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              style: const ButtonStyle(alignment: Alignment.centerRight),
              icon: const Icon(Icons.more_horiz, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
