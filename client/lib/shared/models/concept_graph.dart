/// 사회학 개념 하나 (서버의 Tag).
class ConceptNode {
  const ConceptNode({
    required this.id,
    required this.name,
    this.scrapCount = 0,
    this.createdAt,
  });

  final String id;
  final String name;

  /// 이 개념이 태그로 붙은 스크랩 수.
  final int scrapCount;

  /// 처음 만들어진 때 (서버 Tag.createdAt). 관리 화면의 "최근 추가순"에 쓴다.
  final DateTime? createdAt;

  ConceptNode copyWith({int? scrapCount}) => ConceptNode(
    id: id,
    name: name,
    scrapCount: scrapCount ?? this.scrapCount,
    createdAt: createdAt,
  );
}

enum ConceptLinkStatus {
  /// 사용자가 확정한 연결 (실선).
  confirmed,

  /// AI가 제안했고 아직 승인 전인 연결 (점선).
  suggested,
}

/// 두 개념 사이의 연결. 방향은 없다.
class ConceptLink {
  const ConceptLink(
    this.sourceId,
    this.targetId, {
    this.status = ConceptLinkStatus.confirmed,
    this.reason,
  });

  final String sourceId;
  final String targetId;
  final ConceptLinkStatus status;

  /// 두 개념이 이어지는 이유 (AI 제안 또는 사용자가 쓴 설명).
  final String? reason;

  bool get isSuggested => status == ConceptLinkStatus.suggested;

  bool touches(String id) => sourceId == id || targetId == id;

  String otherEnd(String id) => sourceId == id ? targetId : sourceId;

  /// 방향 없이 같은 두 개념을 잇는지.
  bool connects(String a, String b) =>
      (sourceId == a && targetId == b) || (sourceId == b && targetId == a);

  ConceptLink copyWith({
    String? sourceId,
    String? targetId,
    ConceptLinkStatus? status,
    String? reason,
  }) => ConceptLink(
    sourceId ?? this.sourceId,
    targetId ?? this.targetId,
    status: status ?? this.status,
    reason: reason ?? this.reason,
  );
}

class ConceptGraph {
  ConceptGraph({required this.nodes, required this.links})
    : _byId = {for (final n in nodes) n.id: n};

  final List<ConceptNode> nodes;
  final List<ConceptLink> links;
  final Map<String, ConceptNode> _byId;

  ConceptNode? node(String id) => _byId[id];

  Iterable<ConceptLink> linksOf(String id) => links.where((l) => l.touches(id));

  int get confirmedLinkCount => links.where((l) => !l.isSuggested).length;

  int get suggestedLinkCount => links.where((l) => l.isSuggested).length;

  /// 스크랩이 가장 많이 붙은 개념. 홈 미리보기의 가운데 개념으로 쓴다.
  ConceptNode? get mostScrapped => nodes.isEmpty
      ? null
      : nodes.reduce((a, b) => b.scrapCount > a.scrapCount ? b : a);
}
