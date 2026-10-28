import 'package:client/features/scrap/scrap_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('기사 주소', () {
    test('http(s)와 도메인이 있으면 통과', () {
      expect(ScrapValidators.articleUrl('https://hani.co.kr/arti/1'), isNull);
      expect(ScrapValidators.articleUrl('  http://a.com  '), isNull);
    });

    test('형식이 다르면 오류 문구', () {
      for (final bad in [
        '',
        'hani.co.kr/arti',
        'ftp://a.com',
        'https://',
        'https://localhost',
      ]) {
        expect(
          ScrapValidators.articleUrl(bad),
          ScrapValidators.articleUrlMessage,
          reason: bad,
        );
      }
    });

    test('화면 표시용으로 https://를 뗀다', () {
      expect(
        ScrapValidators.withoutScheme('https://hani.co.kr/arti/society/1162'),
        'hani.co.kr/arti/society/1162',
      );
    });
  });

  group('책', () {
    test('제목은 필수', () {
      expect(ScrapValidators.bookTitle('  '), ScrapValidators.bookTitleMessage);
      expect(ScrapValidators.bookTitle('자살론'), isNull);
    });

    test('페이지는 비어 있거나 양의 정수', () {
      expect(ScrapValidators.page(''), isNull);
      expect(ScrapValidators.page('214'), isNull);
      expect(ScrapValidators.page('0'), ScrapValidators.pageMessage);
      expect(ScrapValidators.page('이백'), ScrapValidators.pageMessage);
    });
  });
}
