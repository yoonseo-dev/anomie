import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/concept_graph.dart';

/// 마인드맵에서 지나온 개념 경로 ("문화자본 → 상대적 박탈감 → 아노미").
/// 마지막 [maxVisible]개만 보이고, 앞 개념을 누르면 그 개념으로 돌아간다.
class MapBreadcrumb extends StatelessWidget {
  const MapBreadcrumb({
    super.key,
    required this.trail,
    required this.onTap,
    this.maxVisible = 3,
  });

  final List<ConceptNode> trail;
  final ValueChanged<String> onTap;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (trail.isEmpty) return const SizedBox.shrink();

    final hidden = trail.length > maxVisible;
    final visible = hidden ? trail.sublist(trail.length - maxVisible) : trail;
    final arrow = Text('→', style: AppTypography.caption);

    return Semantics(
      label: '지나온 개념',
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hidden) ...[
            Text('…', style: AppTypography.caption),
            const SizedBox(width: 6),
            arrow,
            const SizedBox(width: 6),
          ],
          for (final (i, item) in visible.indexed) ...[
            if (i > 0) ...[
              const SizedBox(width: 6),
              arrow,
              const SizedBox(width: 6),
            ],
            Flexible(
              child: _Crumb(
                name: item.name,
                isCurrent: i == visible.length - 1,
                onTap: () => onTap(item.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({
    required this.name,
    required this.isCurrent,
    required this.onTap,
  });

  final String name;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      name,
      style: isCurrent ? AppTypography.captionStrong : AppTypography.caption,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (isCurrent) return text;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: text,
        ),
      ),
    );
  }
}
