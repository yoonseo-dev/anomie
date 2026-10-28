import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/text_link_button.dart';

/// 태그 탭 한 줄 (Figma 18:192). 이름·개수 + 병합/삭제.
class ConceptListRow extends StatelessWidget {
  const ConceptListRow({
    super.key,
    required this.name,
    required this.scrapCount,
    required this.linkCount,
    required this.onOpen,
    required this.onMerge,
    required this.onDelete,
  });

  final String name;
  final int scrapCount;
  final int linkCount;
  final VoidCallback onOpen;
  final VoidCallback onMerge;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.black)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '스크랩 $scrapCount   연결 $linkCount',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          TextLinkButton(label: '병합', onPressed: onMerge),
          const SizedBox(width: 14),
          TextLinkButton(label: '삭제', onPressed: onDelete),
        ],
      ),
    );
  }
}
