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
    this.explanation = '',
    this.category,
    this.description,
  });

  final String name;

  /// 이 글에 이 태그를 붙인 이유.
  final String reason;

  /// 내 개념 목록에 아직 없는 새 태그인지.
  final bool isNew;

  /// 새 태그일 때 바꿔 쓸 수 있는 비슷한 내 태그들.
  final List<String> similarExisting;

  /// 이 글에서 개념이 어떻게 드러나는지 (서버 ArticleTag.explanation).
  final String explanation;

  /// 분야 (통계용, 화면에는 보이지 않는다).
  final String? category;

  /// 새 태그일 때 AI가 쓴 개념 설명. 기존 태그면 null.
  final String? description;
}

/// 스크랩 분석 결과. 태그 확인 화면으로 넘긴다.
class ScrapAnalysis {
  const ScrapAnalysis({
    required this.source,
    required this.title,
    required this.origin,
    required this.sourceName,
    required this.tags,
    this.draft = const {},
  });

  final ScrapSource source;
  final String title;

  /// "한겨레 · 10월 8일", "자살론 · 214쪽" 같은 출처 한 줄.
  final String origin;

  /// 언론사 또는 책 제목만 ("한겨레", "자살론").
  final String sourceName;

  final List<SuggestedTag> tags;

  /// 서버가 분석해 준 원본 (기사 본문·요약·분석 필드 등). 저장할 때 그대로 돌려보낸다.
  /// 서버는 저장 전까지 아무것도 보관하지 않으므로 앱이 들고 있어야 한다 (doc/plan.md 1-4).
  final Map<String, Object?> draft;
}

/// 사용자가 확인을 마친 태그 하나. 이 목록으로 스크랩을 저장한다.
class ApprovedTag {
  const ApprovedTag({
    required this.name,
    required this.reason,
    this.explanation = '',
    this.category,
    this.description,
  });

  /// 저장할 태그 이름. 내 개념 이름과 같으면 서버가 그 개념에 붙인다.
  final String name;
  final String reason;
  final String explanation;

  /// 새 개념으로 만들 때만 쓴다.
  final String? category;
  final String? description;

  Map<String, Object?> toJson() => {
    'name': name,
    'reason': reason,
    'explanation': explanation,
    'category': ?category,
    'description': ?description,
  };
}
