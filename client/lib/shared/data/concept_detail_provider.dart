import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/concept_detail.dart';
import 'concept_graph_repository.dart';
import 'concept_repository.dart';
import 'scrap_repository.dart';

/// 개념 id로 상세 정보를 모은다. 개념이 없으면 null.
///
/// 스크랩을 저장하거나 설명을 수정하면 `ref.invalidate(conceptDetailProvider)`로
/// 다시 불러온다.
final conceptDetailProvider = FutureProvider.autoDispose
    .family<ConceptDetail?, String>((ref, conceptId) async {
      final graph = await ref.watch(conceptGraphProvider.future);
      final concept = graph.node(conceptId);
      if (concept == null) return null;

      final (scraps, description) = await (
        ref.watch(scrapRepositoryProvider).fetchByConcept(concept.name),
        ref.watch(conceptRepositoryProvider).fetchDescription(conceptId),
      ).wait;

      final links = [
        for (final link in graph.linksOf(conceptId))
          if (graph.node(link.otherEnd(conceptId)) case final other?)
            LinkedConcept(concept: other, link: link),
      ];
      // 확정된 연결을 먼저 보여 준다. 같은 종류 안에서는 원래 순서를 지킨다.
      final ordered = [
        ...links.where((l) => !l.link.isSuggested),
        ...links.where((l) => l.link.isSuggested),
      ];

      return ConceptDetail(
        concept: concept,
        graph: graph,
        description: description,
        scraps: scraps,
        links: ordered,
      );
    });
