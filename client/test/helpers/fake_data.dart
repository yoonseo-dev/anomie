import 'package:client/shared/data/concept_graph_repository.dart';
import 'package:client/shared/data/concept_repository.dart';
import 'package:client/shared/data/page_photo_source.dart';
import 'package:client/shared/data/scrap_analysis_repository.dart';
import 'package:client/shared/data/scrap_repository.dart';
import 'package:client/shared/models/scrap_analysis.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// 앱 전체를 띄우는 테스트용 데이터 저장소. 기본 Provider는 서버 API를 부르므로
/// 테스트에서는 항상 가짜 저장소(지연 없음)로 바꾼다. 필요한 것만 골라 바꿔 넣을 수 있다.
/// 개념 저장소는 같은 가짜 스크랩 저장소에서 개념별 스크랩을 찾는다.
List<Override> fakeData({
  ConceptGraphRepository? graph,
  ScrapRepository? scraps,
  ConceptRepository? concepts,
  ScrapAnalysisRepository? analysis,
  PagePhotoSource? photos,
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
    // 기기 카메라·앨범(플러그인)을 부르지 않게 한다.
    pagePhotoSourceProvider.overrideWithValue(photos ?? FakePagePhotoSource()),
  ];
}

/// 고를 때마다 같은 가짜 사진을 돌려준다. [photo]가 null이면 사용자가 취소한 것,
/// [error]가 있으면 권한 거부처럼 실패한다. 어디서 골랐는지는 [picked]에 남는다.
class FakePagePhotoSource implements PagePhotoSource {
  FakePagePhotoSource({PagePhoto? photo, this.cancel = false, this.error})
    : photo = photo ?? PagePhoto(bytes: Uint8List.fromList([1, 2, 3]));

  final PagePhoto photo;
  final bool cancel;
  final Object? error;
  final picked = <PhotoOrigin>[];

  @override
  Future<PagePhoto?> pick(PhotoOrigin origin) async {
    picked.add(origin);
    if (error case final e?) throw e;
    return cancel ? null : photo;
  }
}
