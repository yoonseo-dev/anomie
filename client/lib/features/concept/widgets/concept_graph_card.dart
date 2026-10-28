import 'package:flutter/material.dart';

import '../../../shared/models/concept_graph.dart';
import '../../../shared/widgets/concept_graph/concept_graph_view.dart';
import '../../../shared/widgets/outlined_card.dart';

/// 상세 화면의 연결 미리보기 (Figma 18:25). 누르면 마인드맵에서 이 개념을 연다.
class ConceptGraphCard extends StatelessWidget {
  const ConceptGraphCard({
    super.key,
    required this.graph,
    required this.conceptId,
    required this.onTap,
  });

  final ConceptGraph graph;
  final String conceptId;
  final VoidCallback onTap;

  /// Figma 카드 비율 (335 × 190).
  static const aspectRatio = 335 / 190;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '마인드맵에서 보기',
      child: OutlinedCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: ConceptGraphPreview(
                    graph: graph,
                    focusId: conceptId,
                    style: ConceptGraphStyle.compact,
                    padding: const EdgeInsets.all(16),
                    minScale: 0.85,
                  ),
                ),
              ),
              const Positioned(
                right: 10,
                top: 8,
                child: ExcludeSemantics(
                  child: Icon(Icons.north_east, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
