enum ScrapSource {
  article,
  book;

  /// 라우트 쿼리 값(`?type=article`)에서 읽는다. 모르는 값이면 기사로 본다.
  static ScrapSource fromQuery(String? value) =>
      values.firstWhere((s) => s.name == value, orElse: () => article);
}

/// 스크랩 한 건 (기사 또는 책 구절).
class Scrap {
  const Scrap({
    required this.id,
    required this.source,
    required this.title,
    required this.origin,
    required this.conceptNames,
    required this.savedOn,
    String? originDetail,
    String? sourceName,
    this.explanations = const {},
  }) : originDetail = originDetail ?? origin,
       sourceName = sourceName ?? origin;

  final String id;
  final ScrapSource source;
  final String title;

  /// 기사라면 언론사, 책이라면 "자살론 214쪽"처럼 책 제목과 쪽수.
  final String origin;

  /// 상세 화면용 출처 한 줄 ("한겨레 · 10월 8일", "자살론 · 에밀 뒤르켐 · 214쪽").
  final String originDetail;

  /// 언론사 또는 책 제목만 ("한겨레", "자살론"). "자살론에서 처음 등장" 같은 문장에 쓴다.
  final String sourceName;

  final List<String> conceptNames;

  final DateTime savedOn;

  /// 개념 이름 → 이 글에서 그 개념을 붙인 이유 (서버 ArticleTag.explanation).
  final Map<String, String> explanations;

  Scrap copyWith({
    List<String>? conceptNames,
    Map<String, String>? explanations,
  }) => Scrap(
    id: id,
    source: source,
    title: title,
    origin: origin,
    originDetail: originDetail,
    sourceName: sourceName,
    savedOn: savedOn,
    conceptNames: conceptNames ?? this.conceptNames,
    explanations: explanations ?? this.explanations,
  );

  /// 목록 오른쪽에 보이는 태그 요약 ("아노미 외 1").
  String get conceptSummary => switch (conceptNames.length) {
    0 => '',
    1 => conceptNames.first,
    final n => '${conceptNames.first} 외 ${n - 1}',
  };
}
