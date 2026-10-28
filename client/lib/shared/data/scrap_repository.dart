import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scrap.dart';

abstract interface class ScrapRepository {
  Future<List<Scrap>> fetchRecent({int limit = 3});

  /// [conceptName] 태그가 붙은 스크랩. 최근에 저장한 것부터.
  Future<List<Scrap>> fetchByConcept(String conceptName);

  /// 모든 스크랩에서 태그 이름을 바꾼다 (태그 병합). 이미 [to]가 붙어 있으면 하나로 합친다.
  Future<void> renameConcept(String from, String to);

  /// 모든 스크랩에서 태그를 뺀다 (태그 삭제).
  Future<void> removeConcept(String name);

  /// 태그를 확정한 스크랩을 저장한다.
  Future<Scrap> save({
    required ScrapSource source,
    required String title,
    required String origin,
    required String originDetail,
    required String sourceName,
    required List<String> conceptNames,
    Map<String, String> explanations = const {},
  });
}

/// 서버 연결 전까지 쓰는 가짜 저장소. 앱이 켜져 있는 동안 메모리에만 저장한다.
/// 처음 내용은 Figma 홈(14:16)과 태그 상세(18:12) 화면의 스크랩이다.
class FakeScrapRepository implements ScrapRepository {
  FakeScrapRepository({
    this.delay = const Duration(milliseconds: 300),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration delay;
  final DateTime Function() _now;

  final List<Scrap> _scraps = [..._seed];
  var _nextId = _seed.length + 1;

  static final _seed = [
    Scrap(
      id: 's1',
      source: ScrapSource.article,
      title: '청년 고용률 4년 만에 하락 전환',
      origin: '한겨레',
      originDetail: '한겨레 · 10월 8일',
      savedOn: DateTime(2026, 10, 8),
      conceptNames: const ['아노미', '상대적 박탈감'],
      explanations: const {
        '아노미': '첫 일자리까지의 경로가 길고 불확실해지며, 목표의 기준이 흔들리는 상황.',
        '상대적 박탈감': '또래나 부모 세대와 비교해 기대한 몫을 얻지 못한다는 인식.',
      },
    ),
    Scrap(
      id: 's2',
      source: ScrapSource.book,
      title: '규범이 느슨해질 때 욕망은 한계를 잃는다',
      origin: '자살론 214쪽',
      originDetail: '자살론 · 에밀 뒤르켐 · 214쪽',
      sourceName: '자살론',
      savedOn: DateTime(2026, 9, 21),
      conceptNames: const ['아노미'],
      explanations: const {'아노미': '개념이 처음 정식화된 대목.'},
    ),
    Scrap(
      id: 's3',
      source: ScrapSource.article,
      title: '배달 라이더 3명 중 1명, 하루 10시간',
      origin: '경향신문',
      originDetail: '경향신문 · 10월 9일',
      savedOn: DateTime(2026, 10, 9),
      conceptNames: const ['불안정 노동', '아노미'],
      explanations: const {
        '불안정 노동': '알고리즘이 일감을 배정하는 플랫폼 노동의 불안정한 조건을 다룹니다.',
        '아노미': '플랫폼 규칙이 수시로 바뀌어 기댈 기준이 없다는 점.',
      },
    ),
  ];

  @override
  Future<List<Scrap>> fetchRecent({int limit = 3}) async {
    await Future<void>.delayed(delay);
    return _scraps.take(limit).toList();
  }

  @override
  Future<List<Scrap>> fetchByConcept(String conceptName) async {
    await Future<void>.delayed(delay);
    return _scraps.where((s) => s.conceptNames.contains(conceptName)).toList()
      ..sort((a, b) => b.savedOn.compareTo(a.savedOn));
  }

  @override
  Future<void> renameConcept(String from, String to) async {
    await Future<void>.delayed(delay);
    for (var i = 0; i < _scraps.length; i++) {
      final s = _scraps[i];
      if (!s.conceptNames.contains(from)) continue;
      final explanations = {...s.explanations};
      final moved = explanations.remove(from);
      // 합쳐지는 쪽의 풀이가 이미 있으면 그대로 두고, 없으면 옮겨 온다.
      if (moved != null) explanations.putIfAbsent(to, () => moved);
      _scraps[i] = s.copyWith(
        conceptNames: {
          for (final n in s.conceptNames) n == from ? to : n,
        }.toList(),
        explanations: explanations,
      );
    }
  }

  @override
  Future<void> removeConcept(String name) async {
    await Future<void>.delayed(delay);
    for (var i = 0; i < _scraps.length; i++) {
      final s = _scraps[i];
      if (!s.conceptNames.contains(name)) continue;
      _scraps[i] = s.copyWith(
        conceptNames: [...s.conceptNames]..remove(name),
        explanations: {...s.explanations}..remove(name),
      );
    }
  }

  @override
  Future<Scrap> save({
    required ScrapSource source,
    required String title,
    required String origin,
    required String originDetail,
    required String sourceName,
    required List<String> conceptNames,
    Map<String, String> explanations = const {},
  }) async {
    await Future<void>.delayed(delay);
    final scrap = Scrap(
      id: 's${_nextId++}',
      source: source,
      title: title,
      origin: origin,
      originDetail: originDetail,
      sourceName: sourceName,
      savedOn: _now(),
      conceptNames: List.unmodifiable(conceptNames),
      explanations: Map.unmodifiable(explanations),
    );
    _scraps.insert(0, scrap);
    return scrap;
  }
}

final scrapRepositoryProvider = Provider<ScrapRepository>(
  (ref) => FakeScrapRepository(),
);

final recentScrapsProvider = FutureProvider<List<Scrap>>(
  (ref) => ref.watch(scrapRepositoryProvider).fetchRecent(),
);
