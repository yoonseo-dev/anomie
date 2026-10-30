import 'package:client/shared/data/concept_graph_repository.dart';
import 'package:client/shared/data/concept_repository.dart';
import 'package:client/shared/data/scrap_analysis_repository.dart';
import 'package:client/shared/data/scrap_repository.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// 앱 전체를 띄우는 테스트용 데이터 저장소. 기본 Provider는 서버 API를 부르므로
/// 테스트에서는 항상 가짜 저장소(지연 없음)로 바꾼다. 필요한 것만 골라 바꿔 넣을 수 있다.
/// 개념 저장소는 같은 가짜 스크랩 저장소에서 개념별 스크랩을 찾는다.
List<Override> fakeData({
  ConceptGraphRepository? graph,
  ScrapRepository? scraps,
  ConceptRepository? concepts,
  ScrapAnalysisRepository? analysis,
}) {
  final scrapRepo = scraps ?? FakeScrapRepository(delay: Duration.zero);
  return [
    conceptGraphRepositoryProvider.overrideWithValue(
      graph ?? FakeConceptGraphRepository(delay: Duration.zero),
    ),
    scrapRepositoryProvider.overrideWithValue(scrapRepo),
    conceptRepositoryProvider.overrideWithValue(
      concepts ??
          FakeConceptRepository(delay: Duration.zero, scraps: scrapRepo),
    ),
    scrapAnalysisRepositoryProvider.overrideWithValue(
      analysis ?? const FakeScrapAnalysisRepository(delay: Duration.zero),
    ),
  ];
}
