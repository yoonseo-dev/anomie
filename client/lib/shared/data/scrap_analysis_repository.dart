import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scrap.dart';
import '../models/scrap_analysis.dart';
import 'api_client.dart';

abstract interface class ScrapAnalysisRepository {
  Future<ScrapAnalysis> analyzeArticle(String url);

  Future<ScrapAnalysis> analyzeBookPage({
    required PagePhoto photo,
    required String title,
    String? author,
    int? page,
  });
}

/// 서버 연결 전까지 쓰는 가짜 분석. Figma 태그 확인 화면(17:15)의 내용을 돌려준다.
class FakeScrapAnalysisRepository implements ScrapAnalysisRepository {
  const FakeScrapAnalysisRepository({this.delay = const Duration(seconds: 1)});

  final Duration delay;

  static const _tags = [
    SuggestedTag(
      name: '상대적 박탈감',
      reason: '또래나 부모 세대와 비교해 기대한 몫을 얻지 못한다는 청년층의 인식이 기사의 중심입니다.',
    ),
    SuggestedTag(
      name: '아노미',
      reason: '첫 일자리까지의 경로가 길고 불확실해지며, 무엇을 목표로 삼을지의 기준이 흔들리는 상황입니다.',
    ),
    SuggestedTag(
      name: '이행기 지연',
      reason: '학교에서 안정된 일자리로 넘어가는 기간이 길어지는 현상을 직접 다룹니다.',
      isNew: true,
      similarExisting: ['불안정 노동', '위험사회'],
    ),
  ];

  @override
  Future<ScrapAnalysis> analyzeArticle(String url) async {
    await Future<void>.delayed(delay);
    return const ScrapAnalysis(
      source: ScrapSource.article,
      title: '청년 고용률 4년 만에 하락 전환, 첫 일자리까지 평균 11개월',
      origin: '한겨레 · 10월 8일',
      sourceName: '한겨레',
      tags: _tags,
    );
  }

  @override
  Future<ScrapAnalysis> analyzeBookPage({
    required PagePhoto photo,
    required String title,
    String? author,
    int? page,
  }) async {
    await Future<void>.delayed(delay);
    return ScrapAnalysis(
      source: ScrapSource.book,
      title: '규범이 느슨해질 때 욕망은 한계를 잃는다',
      origin: [title, ?author, if (page != null) '$page쪽'].join(' · '),
      sourceName: title,
      tags: const [
        SuggestedTag(
          name: '아노미',
          reason: '사회적 규범이 약해질 때 개인의 욕망을 조절할 기준이 사라진다는 뒤르켐의 핵심 논지입니다.',
          excerpt: '규범이 힘을 잃으면 욕망은 더 이상 한계를 알지 못한다.',
        ),
        SuggestedTag(
          name: '사회적 통합',
          reason: '개인을 사회에 묶어 두는 힘이 약해지는 과정을 함께 설명합니다.',
          isNew: true,
          excerpt: '사회가 개인을 붙잡는 힘이 약해질수록',
          excerptVerified: false,
        ),
      ],
      draft: {
        'bookTitle': title,
        'author': ?author,
        'page': ?page,
        'summary': '규범이 느슨해질 때 욕망은 한계를 잃는다',
      },
    );
  }
}

/// 서버 API 분석 (`POST /articles/analyze`). 서버는 분석만 하고 저장하지 않는다.
class ApiScrapAnalysisRepository implements ScrapAnalysisRepository {
  ApiScrapAnalysisRepository(this._dio);

  final Dio _dio;

  static String _date(DateTime d) => '${d.month}월 ${d.day}일';

  /// 분석 응답의 태그 한 건. similarExisting은 [{id, name}]이고 화면에는 이름만 쓴다.
  static SuggestedTag tagFromJson(Map<String, dynamic> t) => SuggestedTag(
    name: t['name'] as String,
    reason: t['reason'] as String,
    isNew: t['isNew'] as bool,
    similarExisting: [
      for (final s in (t['similarExisting'] as List? ?? const []))
        (s as Map<String, dynamic>)['name'] as String,
    ],
    explanation: (t['explanation'] as String?) ?? '',
    category: t['category'] as String?,
    description: t['description'] as String?,
    excerpt: t['excerpt'] as String?,
    excerptVerified: (t['excerptVerified'] as bool?) ?? true,
  );

  /// `POST /articles/analyze` 응답. tags 외의 값은 저장할 때 그대로 돌려보낸다.
  static ScrapAnalysis articleFromJson(Map<String, dynamic> json) {
    final url = json['url'] as String;
    final publisher =
        (json['publisher'] as String?) ??
        (Uri.tryParse(url)?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
    final published = switch (json['publishedAt']) {
      final String s => DateTime.parse(s).toLocal(),
      _ => null,
    };
    return ScrapAnalysis(
      source: ScrapSource.article,
      title: json['title'] as String,
      origin: [
        if (publisher.isNotEmpty) publisher,
        if (published != null) _date(published),
      ].join(' · '),
      sourceName: publisher,
      tags: [
        for (final t in (json['tags'] as List).cast<Map<String, dynamic>>())
          tagFromJson(t),
      ],
      draft: {...json}..remove('tags'),
    );
  }

  @override
  Future<ScrapAnalysis> analyzeArticle(String url) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/articles/analyze',
        data: {'url': url},
        options: analyzeOptions,
      );
      return articleFromJson(res.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// `POST /book-scraps/analyze` 응답. 책은 제목 자리에 요약을 쓴다 (10-29 결정).
  /// ocrText는 draft에 남지만 저장할 때 빠진다 ([ApiScrapRepository.save]).
  static ScrapAnalysis bookFromJson(Map<String, dynamic> json) {
    final bookTitle = json['bookTitle'] as String;
    final author = json['author'] as String?;
    final page = json['page'] as int?;
    return ScrapAnalysis(
      source: ScrapSource.book,
      title: json['summary'] as String,
      origin: [bookTitle, ?author, if (page != null) '$page쪽'].join(' · '),
      sourceName: bookTitle,
      tags: [
        for (final t in (json['tags'] as List).cast<Map<String, dynamic>>())
          tagFromJson(t),
      ],
      draft: {...json}..remove('tags'),
    );
  }

  @override
  Future<ScrapAnalysis> analyzeBookPage({
    required PagePhoto photo,
    required String title,
    String? author,
    int? page,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/book-scraps/analyze',
        data: FormData.fromMap({
          'image': MultipartFile.fromBytes(photo.bytes, filename: photo.name),
          'bookTitle': title,
          'author': ?author,
          'page': ?page?.toString(),
        }),
        options: analyzeOptions,
      );
      return bookFromJson(res.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

final scrapAnalysisRepositoryProvider = Provider<ScrapAnalysisRepository>(
  (ref) => ApiScrapAnalysisRepository(ref.watch(apiClientProvider)),
);

/// 가장 최근 분석 결과. 태그 확인 화면이 읽는다.
class LatestAnalysisNotifier extends Notifier<ScrapAnalysis?> {
  @override
  ScrapAnalysis? build() => null;

  void set(ScrapAnalysis? analysis) => state = analysis;
}

final latestAnalysisProvider =
    NotifierProvider<LatestAnalysisNotifier, ScrapAnalysis?>(
      LatestAnalysisNotifier.new,
    );
