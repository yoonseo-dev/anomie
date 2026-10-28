import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/concept_graph.dart';

/// "+N" 묶음을 눌렀을 때 숨겨 둔 개념 목록을 보여 준다.
/// 하나를 고르면 그 개념 id를 돌려주며 닫힌다.
class HiddenConceptsSheet extends StatelessWidget {
  const HiddenConceptsSheet({
    super.key,
    required this.parentName,
    required this.concepts,
  });

  final String parentName;
  final List<ConceptNode> concepts;

  static Future<String?> show(
    BuildContext context, {
    required String parentName,
    required List<ConceptNode> concepts,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        maxWidth: AppSpacing.maxContentWidth,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (_) =>
          HiddenConceptsSheet(parentName: parentName, concepts: concepts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.sm,
            ),
            child: Text.rich(
              TextSpan(
                text: '$parentName에 연결된 개념',
                children: [
                  TextSpan(
                    text: '  ${concepts.length}',
                    style: AppTypography.body,
                  ),
                ],
              ),
              style: AppTypography.section,
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: concepts.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) {
                final c = concepts[i];
                return InkWell(
                  onTap: () => Navigator.of(context).pop(c.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            style: AppTypography.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '스크랩 ${c.scrapCount}',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
