import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../models/scrap.dart';
import '../models/scrap_analysis.dart';
import 'api_client.dart';

abstract interface class ScrapRepository {
  Future<List<Scrap>> fetchRecent({int limit = 3});

  /// [conceptName] 태그가 붙은 스크랩. 최근에 저장한 것부터.
  Future<List<Scrap>> fetchByConcept(String conceptName);

  /// 모든 스크랩에서 태그 이름을 바꾼다 (태그 병합). 이미 [to]가 붙어 있으면 하나로 합친다.
  Future<void> renameConcept(String from, String to);

  /// 모든 스크랩에서 태그를 뺀다 (태그 삭제).
  Future<void> removeConcept(String name);

  /// 분석 결과를 사용자가 확인한 태그와 함께 저장한다.
  Future<Scrap> save(ScrapAnalysis analysis, List<ApprovedTag> tags);
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
  Future<Scrap> save(ScrapAnalysis analysis, List<ApprovedTag> tags) async {
    await Future<void>.delayed(delay);
    final scrap = Scrap(
      id: 's${_nextId++}',
      source: analysis.source,
      title: analysis.title,
      // 홈 목록에는 짧게, 상세 화면에는 날짜·저자까지 보여 준다.
      origin: analysis.sourceName,
      originDetail: analysis.origin,
      sourceName: analysis.sourceName,
      savedOn: _now(),
      conceptNames: List.unmodifiable(tags.map((t) => t.name)),
      explanations: Map.unmodifiable({for (final t in tags) t.name: t.reason}),
    );
    _scraps.insert(0, scrap);
    return scrap;
  }
}

/// 서버 API 저장소 (`/articles`, `/book-scraps`).
class ApiScrapRepository implements ScrapRepository {
  ApiScrapRepository(this._dio);

  final Dio _dio;

  static String _date(DateTime d) => '${d.month}월 ${d.day}일';

  static DateTime _time(Object? value) =>
      DateTime.parse(value as String).toLocal();

  /// 태그 연결 목록에서 개념 이름·풀이·근거 문장을 꺼낸다. 풀이가 비면 이유를 쓴다.
  static (List<String>, Map<String, String>, Map<String, String>) _tags(
    Object? links,
  ) {
    final names = <String>[];
    final explanations = <String, String>{};
    final excerpts = <String, String>{};
    for (final link
        in (links as List? ?? const []).cast<Map<String, dynamic>>()) {
      final name = (link['tag'] as Map<String, dynamic>)['name'] as String;
      names.add(name);
      explanations[name] = switch (link['explanation']) {
        final String e when e.isNotEmpty => e,
        _ => link['reason'] as String,
      };
      if (link['excerpt'] case final String e) excerpts[name] = e;
    }
    return (names, explanations, excerpts);
  }

  /// `GET /articles` 한 건 (articleTags.tag 포함).
  static Scrap articleFromJson(Map<String, dynamic> a) {
    final savedOn = _time(a['createdAt']);
    final publisher =
        (a['publisher'] as String?) ??
        Uri.tryParse(a['url'] as String? ?? '')?.host ??
        '';
    final (names, explanations, _) = _tags(a['articleTags']);
    // 출처 줄의 날짜는 분석 화면처럼 기사 발행일, 없으면 저장한 날
    final published = a['publishedAt'] == null
        ? savedOn
        : _time(a['publishedAt']);
    return Scrap(
      id: a['id'] as String,
      source: ScrapSource.article,
      title: a['title'] as String,
      origin: publisher,
      originDetail: [
        if (publisher.isNotEmpty) publisher,
        _date(published),
      ].join(' · '),
      sourceName: publisher,
      savedOn: savedOn,
      conceptNames: names,
      explanations: explanations,
    );
  }

  /// `GET /book-scraps` 한 건 (bookTags.tag 포함). 책은 제목 자리에 요약을 쓴다 (10-29 결정).
  static Scrap bookFromJson(Map<String, dynamic> b) {
    final bookTitle = b['bookTitle'] as String;
    final page = b['page'] as int?;
    final author = b['author'] as String?;
    final (names, explanations, excerpts) = _tags(b['bookTags']);
    return Scrap(
      id: b['id'] as String,
      source: ScrapSource.book,
      title: b['summary'] as String,
      origin: [bookTitle, if (page != null) '$page쪽'].join(' '),
      originDetail: [
        bookTitle,
        ?author,
        if (page != null) '$page쪽',
      ].join(' · '),
      sourceName: bookTitle,
      savedOn: _time(b['createdAt']),
      conceptNames: names,
      explanations: explanations,
      excerpts: excerpts,
    );
  }

  Future<List<Scrap>> _list(
    String path,
    Scrap Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final res = await _dio.get<List<dynamic>>(path);
      return [
        for (final item in res.data ?? const [])
          fromJson(item as Map<String, dynamic>),
      ];
    } catch (e, s) {
      throw ApiException.from(e, s);
    }
  }

  /// 기사와 책을 합쳐 최근에 저장한 것부터 (각각 서버 첫 페이지 20건 안에서).
  Future<List<Scrap>> _recentAll() async {
    final [articles, books] = await Future.wait([
      _list('/articles', articleFromJson),
      _list('/book-scraps', bookFromJson),
    ]);
    return [...articles, ...books]
      ..sort((a, b) => b.savedOn.compareTo(a.savedOn));
  }

  @override
  Future<List<Scrap>> fetchRecent({int limit = 3}) async =>
      (await _recentAll()).take(limit).toList();

  /// 개념 상세는 `GET /concepts/:id`를 쓰므로, 이건 최근 스크랩 안에서만 찾는다.
  @override
  Future<List<Scrap>> fetchByConcept(String conceptName) async =>
      (await _recentAll())
          .where((s) => s.conceptNames.contains(conceptName))
          .toList();

  // 태그 이름 바꾸기·빼기는 서버가 개념 병합·삭제 때 함께 처리한다.
  @override
  Future<void> renameConcept(String from, String to) async {}

  @override
  Future<void> removeConcept(String name) async {}

  @override
  Future<Scrap> save(ScrapAnalysis analysis, List<ApprovedTag> tags) async {
    final isBook = analysis.source == ScrapSource.book;
    // OCR 전문은 대조용으로만 받았으므로 서버로 돌려보내지 않는다.
    final draft = {...analysis.draft}..remove('ocrText');
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        isBook ? '/book-scraps' : '/articles',
        data: {
          ...draft,
          'tags': [for (final t in tags) t.toJson()],
        },
      );
      return isBook ? bookFromJson(res.data!) : articleFromJson(res.data!);
    } catch (e, s) {
      throw ApiException.from(e, s);
    }
  }
}

final scrapRepositoryProvider = Provider<ScrapRepository>(
  (ref) => ApiScrapRepository(ref.watch(apiClientProvider)),
);

/// 로그인한 사용자가 바뀌면 다시 불러온다.
final recentScrapsProvider = FutureProvider<List<Scrap>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(scrapRepositoryProvider).fetchRecent();
});
