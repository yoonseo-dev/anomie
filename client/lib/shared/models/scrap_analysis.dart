import 'scrap.dart';

/// 촬영한 책 페이지. 실제 카메라를 붙이기 전까지는 [path]가 없는 가짜 사진을 쓴다.
class PagePhoto {
  const PagePhoto({this.path});

  /// 기기에 저장된 사진 경로. null이면 가짜 사진이다.
  final String? path;
}

/// AI가 제안한 태그 하나 (서버 ArticleTag의 reason과 같은 역할).
class SuggestedTag {
  const SuggestedTag({
    required this.name,
    required this.reason,
    this.isNew = false,
    this.similarExisting = const [],
  });

  final String name;

  /// 이 글에 이 태그를 붙인 이유.
  final String reason;

  /// 내 개념 목록에 아직 없는 새 태그인지.
  final bool isNew;

  /// 새 태그일 때 바꿔 쓸 수 있는 비슷한 내 태그들.
  final List<String> similarExisting;
}

/// 스크랩 분석 결과. 태그 확인 화면으로 넘긴다.
class ScrapAnalysis {
  const ScrapAnalysis({
    required this.source,
    required this.title,
    required this.origin,
    required this.sourceName,
    required this.tags,
  });

  final ScrapSource source;
  final String title;

  /// "한겨레 · 10월 8일", "자살론 · 214쪽" 같은 출처 한 줄.
  final String origin;

  /// 언론사 또는 책 제목만 ("한겨레", "자살론").
  final String sourceName;

  final List<SuggestedTag> tags;
}
