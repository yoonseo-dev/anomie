import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/concept_graph.dart';

abstract interface class ConceptGraphRepository {
  Future<ConceptGraph> fetchGraph();

  /// AI 제안 연결을 확정한다.
  Future<void> approveLink(String a, String b);

  /// 연결을 지운다 (제안 거절, 연결 끊기). 지운 연결과 원래 자리를 돌려준다.
  Future<(ConceptLink, int)?> removeLink(String a, String b);

  /// [removeLink]로 지운 연결을 원래 자리에 되돌린다.
  Future<void> restoreLink(ConceptLink link, int index);

  Future<void> updateLinkReason(String a, String b, String reason);

  /// 개념과 그 개념의 연결을 모두 지운다.
  Future<void> deleteConcept(String id);

  /// [fromId] 개념을 [intoId]에 합친다. 연결은 옮기고(겹치면 하나로), [fromId]는 지운다.
  Future<void> mergeConcepts({required String fromId, required String intoId});
}

/// 서버 연결 전까지 쓰는 가짜 저장소. 앱이 켜져 있는 동안 메모리에만 바뀐 내용을 남긴다.
/// 처음 내용은 Figma의 홈·마인드맵·관리 화면에 나온 개념과 연결을 하나로 맞춘 것이다.
class FakeConceptGraphRepository implements ConceptGraphRepository {
  FakeConceptGraphRepository({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;

  late final List<ConceptNode> _nodes = [..._seedNodes];
  late final List<ConceptLink> _links = [..._seedLinks];

  @override
  Future<ConceptGraph> fetchGraph() async {
    await Future<void>.delayed(delay);
    return ConceptGraph(nodes: List.of(_nodes), links: List.of(_links));
  }

  int _indexOf(String a, String b) =>
      _links.indexWhere((l) => l.connects(a, b));

  @override
  Future<void> approveLink(String a, String b) async {
    await Future<void>.delayed(delay);
    final i = _indexOf(a, b);
    if (i >= 0) {
      _links[i] = _links[i].copyWith(status: ConceptLinkStatus.confirmed);
    }
  }

  @override
  Future<(ConceptLink, int)?> removeLink(String a, String b) async {
    await Future<void>.delayed(delay);
    final i = _indexOf(a, b);
    if (i < 0) return null;
    return (_links.removeAt(i), i);
  }

  @override
  Future<void> restoreLink(ConceptLink link, int index) async {
    await Future<void>.delayed(delay);
    if (_indexOf(link.sourceId, link.targetId) >= 0) return;
    _links.insert(index.clamp(0, _links.length), link);
  }

  @override
  Future<void> updateLinkReason(String a, String b, String reason) async {
    await Future<void>.delayed(delay);
    final i = _indexOf(a, b);
    if (i >= 0) _links[i] = _links[i].copyWith(reason: reason);
  }

  @override
  Future<void> deleteConcept(String id) async {
    await Future<void>.delayed(delay);
    _nodes.removeWhere((n) => n.id == id);
    _links.removeWhere((l) => l.touches(id));
  }

  @override
  Future<void> mergeConcepts({
    required String fromId,
    required String intoId,
  }) async {
    await Future<void>.delayed(delay);
    final fromIndex = _nodes.indexWhere((n) => n.id == fromId);
    final intoIndex = _nodes.indexWhere((n) => n.id == intoId);
    if (fromIndex < 0 || intoIndex < 0 || fromId == intoId) return;

    final moved = _links.where((l) => l.touches(fromId)).toList();
    _links.removeWhere((l) => l.touches(fromId));
    for (final link in moved) {
      final other = link.otherEnd(fromId);
      if (other == intoId) continue; // 둘 사이의 연결은 합치면 의미가 없다.
      final existing = _indexOf(intoId, other);
      if (existing < 0) {
        _links.add(link.copyWith(sourceId: intoId, targetId: other));
      } else if (!link.isSuggested && _links[existing].isSuggested) {
        // 한쪽이라도 확정된 연결이었다면 확정으로 남긴다.
        _links[existing] = _links[existing].copyWith(
          status: ConceptLinkStatus.confirmed,
        );
      }
    }

    final from = _nodes[fromIndex];
    _nodes[intoIndex] = _nodes[intoIndex].copyWith(
      scrapCount: _nodes[intoIndex].scrapCount + from.scrapCount,
    );
    _nodes.removeAt(fromIndex);
  }

  static final _seedNodes = [
    ConceptNode(
      id: 'anomie',
      name: '아노미',
      scrapCount: 3,
      createdAt: DateTime(2026, 9, 21),
    ),
    ConceptNode(
      id: 'relative-deprivation',
      name: '상대적 박탈감',
      scrapCount: 2,
      createdAt: DateTime(2026, 10, 8),
    ),
    ConceptNode(
      id: 'solidarity',
      name: '사회적 연대',
      scrapCount: 1,
      createdAt: DateTime(2026, 9, 24),
    ),
    ConceptNode(
      id: 'individualism',
      name: '개인주의',
      createdAt: DateTime(2026, 10, 2),
    ),
    ConceptNode(
      id: 'precarious-labor',
      name: '불안정 노동',
      scrapCount: 2,
      createdAt: DateTime(2026, 10, 9),
    ),
    ConceptNode(
      id: 'norm',
      name: '규범',
      scrapCount: 1,
      createdAt: DateTime(2026, 9, 21),
    ),
    ConceptNode(
      id: 'alienation',
      name: '소외',
      scrapCount: 1,
      createdAt: DateTime(2026, 9, 28),
    ),
    ConceptNode(
      id: 'class-reproduction',
      name: '계급 재생산',
      createdAt: DateTime(2026, 10, 8),
    ),
    ConceptNode(
      id: 'cultural-capital',
      name: '문화자본',
      createdAt: DateTime(2026, 9, 30),
    ),
    ConceptNode(
      id: 'division-of-labor',
      name: '분업',
      createdAt: DateTime(2026, 9, 24),
    ),
    ConceptNode(
      id: 'risk-society',
      name: '위험사회',
      createdAt: DateTime(2026, 10, 9),
    ),
    ConceptNode(
      id: 'platform-labor',
      name: '플랫폼 노동',
      createdAt: DateTime(2026, 10, 9),
    ),
    ConceptNode(
      id: 'disciplinary-power',
      name: '규율 권력',
      createdAt: DateTime(2026, 9, 28),
    ),
    ConceptNode(
      id: 'panopticon',
      name: '판옵티콘',
      createdAt: DateTime(2026, 9, 29),
    ),
    ConceptNode(id: 'habitus', name: '아비투스', createdAt: DateTime(2026, 9, 30)),
    ConceptNode(
      id: 'public-sphere',
      name: '공론장',
      createdAt: DateTime(2026, 10, 5),
    ),
  ];

  static const _seedLinks = [
    ConceptLink(
      'anomie',
      'relative-deprivation',
      reason: '기대와 현실의 격차가 커질 때 규범이 흔들린다는 점.',
    ),
    ConceptLink('anomie', 'solidarity', reason: '연대가 약해질 때 아노미가 나타난다는 대비.'),
    ConceptLink(
      'anomie',
      'individualism',
      status: ConceptLinkStatus.suggested,
      reason: '공동의 규범보다 개인의 판단이 앞설 때 생기는 긴장을 다룬다는 제안.',
    ),
    ConceptLink(
      'anomie',
      'precarious-labor',
      reason: '고용의 규칙이 수시로 바뀌어 기댈 기준이 사라진다는 점.',
    ),
    ConceptLink('anomie', 'norm', reason: '아노미는 규범이 힘을 잃은 상태를 가리킨다는 점.'),
    ConceptLink(
      'anomie',
      'alienation',
      status: ConceptLinkStatus.suggested,
      reason: '개인과 사회의 끊어진 관계를 다룬다는 제안.',
    ),
    ConceptLink(
      'relative-deprivation',
      'class-reproduction',
      reason: '비교의 기준선이 계층에 따라 대물림된다는 점.',
    ),
    ConceptLink(
      'relative-deprivation',
      'cultural-capital',
      reason: '문화적 자원의 차이가 기대 수준의 차이로 이어진다는 점.',
    ),
    ConceptLink(
      'solidarity',
      'division-of-labor',
      reason: '분업이 유기적 연대의 바탕이 된다는 뒤르켐의 논지.',
    ),
    ConceptLink(
      'precarious-labor',
      'risk-society',
      reason: '위험이 개인에게 떠넘겨지는 노동 조건이라는 점.',
    ),
    ConceptLink(
      'precarious-labor',
      'platform-labor',
      reason: '플랫폼 노동이 불안정 노동의 대표적인 형태라는 점.',
    ),
    ConceptLink(
      'alienation',
      'disciplinary-power',
      reason: '통제가 내면화될수록 자기 활동에서 멀어진다는 점.',
    ),
    ConceptLink(
      'disciplinary-power',
      'panopticon',
      reason: '보이지 않는 감시가 스스로를 규율하게 만든다는 모델.',
    ),
    ConceptLink(
      'cultural-capital',
      'habitus',
      reason: '몸에 밴 취향과 성향이 문화자본으로 작동한다는 점.',
    ),
    ConceptLink(
      'public-sphere',
      'cultural-capital',
      status: ConceptLinkStatus.suggested,
      reason: '토론 참여 자격이 문화적 자원에 따라 갈린다는 제안.',
    ),
  ];
}

final conceptGraphRepositoryProvider = Provider<ConceptGraphRepository>(
  (ref) => FakeConceptGraphRepository(),
);

final conceptGraphProvider = FutureProvider<ConceptGraph>(
  (ref) => ref.watch(conceptGraphRepositoryProvider).fetchGraph(),
);
