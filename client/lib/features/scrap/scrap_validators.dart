/// 새 스크랩 입력 검사. 오류 문구를 돌려주고, 문제가 없으면 null.
abstract final class ScrapValidators {
  static const articleUrlMessage = 'https://로 시작하는 기사 주소를 넣어 주세요';
  static const bookTitleMessage = '책 제목을 넣어 주세요';
  static const pageMessage = '숫자만 넣어 주세요';

  /// 기사 주소. http(s)로 시작하고 도메인이 있어야 한다.
  static String? articleUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    final ok =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.contains('.');
    return ok ? null : articleUrlMessage;
  }

  static String? bookTitle(String raw) =>
      raw.trim().isEmpty ? bookTitleMessage : null;

  /// 페이지는 선택 입력이라 비어 있어도 된다.
  static String? page(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final n = int.tryParse(value);
    return n == null || n <= 0 ? pageMessage : null;
  }

  /// 화면에 보여 줄 때 "https://"를 뗀 주소.
  static String withoutScheme(String url) =>
      url.trim().replaceFirst(RegExp(r'^https?://'), '');
}
