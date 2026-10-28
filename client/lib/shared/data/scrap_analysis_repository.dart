import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scrap.dart';
import '../models/scrap_analysis.dart';

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
        ),
      ],
    );
  }
}

final scrapAnalysisRepositoryProvider = Provider<ScrapAnalysisRepository>(
  (ref) => const FakeScrapAnalysisRepository(),
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
