import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/concept_detail.dart';

abstract interface class ConceptRepository {
  Future<ConceptDescription?> fetchDescription(String conceptId);

  Future<void> updateDescription(String conceptId, String text);

  /// 태그를 삭제하거나 병합할 때 설명도 지운다.
  Future<void> deleteDescription(String conceptId);
}

/// 서버 연결 전까지 쓰는 가짜 설명 저장소. 수정한 내용은 메모리에만 남는다.
class FakeConceptRepository implements ConceptRepository {
  FakeConceptRepository({this.delay = const Duration(milliseconds: 200)});

  final Duration delay;

  final Map<String, ConceptDescription> _descriptions = {
    for (final MapEntry(:key, :value) in _seed.entries)
      key: ConceptDescription(text: value, byAi: true),
  };

  static const _seed = {
    'anomie':
        '사회의 규범이 약해지거나 급격히 바뀌어, 개인이 무엇을 기준으로 행동하고 욕망을 조절해야 할지 잃어버린 상태. 뒤르켐이 『사회분업론』과 『자살론』에서 발전시켰다.',
    'relative-deprivation':
        '절대적인 결핍이 아니라, 비교 대상에 비해 자신이 덜 가졌다고 느끼는 상태. 기대 수준과 실제 사이의 격차에서 생긴다.',
    'solidarity':
        '사회 구성원을 서로 묶어 주는 유대. 뒤르켐은 비슷함에 기댄 기계적 연대와 분업에 기댄 유기적 연대를 구분했다.',
    'individualism':
        '공동체보다 개인의 권리와 판단을 앞세우는 생각과 태도. 근대 사회의 핵심 가치이면서 연대를 약하게 만드는 요인으로도 논의된다.',
    'precarious-labor':
        '고용 기간, 소득, 사회보장이 불안정한 노동. 비정규직과 특수고용, 플랫폼 노동 등에서 두드러진다.',
    'norm': '한 사회에서 사람들이 마땅히 따라야 한다고 여기는 행동의 기준. 법처럼 명문화된 것과 관습처럼 암묵적인 것이 있다.',
    'alienation':
        '사람이 자신의 노동, 산물, 다른 사람, 그리고 자기 자신으로부터 멀어지는 상태. 마르크스가 자본주의 노동을 분석하며 발전시켰다.',
    'class-reproduction': '부모 세대의 계급적 위치가 교육과 문화를 거쳐 자녀 세대로 이어지는 과정.',
    'cultural-capital': '교육, 취향, 말투처럼 사회적 이익으로 바뀔 수 있는 문화적 자원. 부르디외가 제시했다.',
    'division-of-labor':
        '일을 여러 사람이 나누어 맡는 것. 뒤르켐은 분업이 사회를 묶는 새로운 연대의 바탕이 된다고 보았다.',
    'risk-society': '산업화가 만든 위험이 사회의 중심 문제가 된 상태. 울리히 벡이 제시했다.',
    'platform-labor': '앱과 알고리즘을 통해 일감이 배정되고 평가되는 노동.',
    'disciplinary-power': '감시와 훈련, 평가를 통해 사람의 몸과 행동을 길들이는 권력. 푸코가 분석했다.',
    'panopticon':
        '한 사람이 모두를 볼 수 있지만 자신은 보이지 않는 감시 구조. 벤담이 설계하고 푸코가 규율 권력의 모델로 삼았다.',
    'habitus': '사회적 경험을 통해 몸에 밴 지각과 행동의 성향. 부르디외가 제시했다.',
    'public-sphere': '시민이 공적 문제를 자유롭게 토론하며 여론을 만드는 공간. 하버마스가 발전시켰다.',
  };

  @override
  Future<ConceptDescription?> fetchDescription(String conceptId) async {
    await Future<void>.delayed(delay);
    return _descriptions[conceptId];
  }

  @override
  Future<void> updateDescription(String conceptId, String text) async {
    await Future<void>.delayed(delay);
    _descriptions[conceptId] = ConceptDescription(text: text, byAi: false);
  }

  @override
  Future<void> deleteDescription(String conceptId) async {
    await Future<void>.delayed(delay);
    _descriptions.remove(conceptId);
  }
}

final conceptRepositoryProvider = Provider<ConceptRepository>(
  (ref) => FakeConceptRepository(),
);
