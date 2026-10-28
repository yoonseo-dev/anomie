import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/concept_detail_provider.dart';
import '../../shared/data/concept_graph_repository.dart';
import '../../shared/data/concept_repository.dart';
import '../../shared/data/scrap_repository.dart';
import '../../shared/models/concept_graph.dart';

/// 관리 화면의 개념·연결 변경. 바꾼 뒤에는 홈·마인드맵·상세가 함께 갱신되도록
/// 관련 데이터를 다시 불러온다.
class ConceptActions {
  ConceptActions(this._ref);

  final Ref _ref;

  ConceptGraphRepository get _graph =>
      _ref.read(conceptGraphRepositoryProvider);

  void _refresh() {
    _ref
      ..invalidate(conceptGraphProvider)
      ..invalidate(conceptDetailProvider)
      ..invalidate(recentScrapsProvider);
  }

  Future<void> approve(ConceptLink link) async {
    await _graph.approveLink(link.sourceId, link.targetId);
    _refresh();
  }

  /// 제안 거절과 연결 끊기. 되돌리기에 쓸 값을 돌려준다.
  Future<(ConceptLink, int)?> remove(ConceptLink link) async {
    final removed = await _graph.removeLink(link.sourceId, link.targetId);
    _refresh();
    return removed;
  }

  Future<void> restore((ConceptLink, int) removed) async {
    await _graph.restoreLink(removed.$1, removed.$2);
    _refresh();
  }

  Future<void> updateReason(ConceptLink link, String reason) async {
    await _graph.updateLinkReason(link.sourceId, link.targetId, reason);
    _refresh();
  }

  /// 개념(태그)을 지운다. 스크랩에서도 이 태그를 뺀다.
  Future<void> delete(ConceptNode concept) async {
    await _graph.deleteConcept(concept.id);
    await _ref.read(scrapRepositoryProvider).removeConcept(concept.name);
    await _ref.read(conceptRepositoryProvider).deleteDescription(concept.id);
    _refresh();
  }

  /// [from]을 [into]에 합친다. 연결과 스크랩 태그를 [into]로 옮긴다.
  Future<void> merge(ConceptNode from, ConceptNode into) async {
    await _graph.mergeConcepts(fromId: from.id, intoId: into.id);
    await _ref
        .read(scrapRepositoryProvider)
        .renameConcept(from.name, into.name);
    await _ref.read(conceptRepositoryProvider).deleteDescription(from.id);
    _refresh();
  }
}

final conceptActionsProvider = Provider<ConceptActions>(ConceptActions.new);
