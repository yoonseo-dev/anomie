import 'concept_graph.dart';
import 'scrap.dart';

/// 개념 설명 (서버 Tag.description).
class ConceptDescription {
  const ConceptDescription({required this.text, required this.byAi});

  final String text;

  /// AI가 쓴 설명인지. 사용자가 수정하면 false가 된다.
  final bool byAi;
}

/// 상세 화면에서 보여 줄 연결 하나.
class LinkedConcept {
  const LinkedConcept({required this.concept, required this.link});

  final ConceptNode concept;
  final ConceptLink link;
}

/// 태그(개념) 상세 화면에 필요한 값을 한데 묶은 것.
class ConceptDetail {
  const ConceptDetail({
    required this.concept,
    required this.graph,
    required this.description,
    required this.scraps,
    required this.links,
  });

  final ConceptNode concept;

  /// 연결 미리보기를 그릴 전체 그래프.
  final ConceptGraph graph;

  final ConceptDescription? description;

  /// 이 개념이 붙은 스크랩. 최근에 저장한 것부터.
  final List<Scrap> scraps;

  /// 확정된 연결이 먼저, 제안이 뒤에 온다.
  final List<LinkedConcept> links;

  int get confirmedCount => links.where((l) => !l.link.isSuggested).length;

  int get suggestedCount => links.where((l) => l.link.isSuggested).length;

  /// 이 개념이 처음 붙은 스크랩.
  Scrap? get firstScrap => scraps.isEmpty
      ? null
      : scraps.reduce((a, b) => b.savedOn.isBefore(a.savedOn) ? b : a);
}
