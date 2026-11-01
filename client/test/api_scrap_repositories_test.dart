import 'dart:typed_data';

import 'package:client/shared/data/api_client.dart';
import 'package:client/shared/data/scrap_analysis_repository.dart';
import 'package:client/shared/data/scrap_repository.dart';
import 'package:client/shared/models/scrap.dart';
import 'package:client/shared/models/scrap_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_server.dart';

void main() {
  late FakeServer server;

  setUp(() => server = FakeServer());

  // POST /articles/analyze 응답 (서버 articleService.analyzeArticle과 같은 모양)
  final analyzed = {
    'url': 'https://www.hani.co.kr/arti/1',
    'title': '청년 고용률 하락',
    'publisher': null,
    'thumbnailUrl': null,
    'publishedAt': '2026-10-08T03:00:00.000Z',
    'content': '본문',
    'summary': '요약',
    'commentary': '평론',
    'framing': null,
    'rhetoric': null,
    'stakeholders': null,
    'values': null,
    'tags': [
      {
        'tagId': 't1',
        'name': '아노미',
        'isNew': false,
        'category': '사회학',
        'description': '규범이 힘을 잃은 상태',
        'reason': '기준이 흔들린다',
        'explanation': '경로가 불확실해진다',
        'similarExisting': <Object>[],
      },
      {
        'tagId': null,
        'name': '이행기 지연',
        'isNew': true,
        'category': '사회학',
        'description': '학교에서 일자리로 넘어가는 기간이 길어지는 현상',
        'reason': '첫 일자리까지 11개월',
        'explanation': '',
        'similarExisting': [
          {'id': 't9', 'name': '불안정 노동'},
        ],
      },
    ],
  };

  group('ApiScrapAnalysisRepository', () {
    test('기사 분석: 언론사가 없으면 도메인, 비슷한 태그는 이름만, 태그 외 값은 저장용 draft로', () async {
      server.responses['POST /articles/analyze'] = (200, analyzed);

      final a = await ApiScrapAnalysisRepository(
        server.dio(),
      ).analyzeArticle('https://www.hani.co.kr/arti/1');

      expect(
        server.requests.single,
        req('POST', '/articles/analyze', {
          'url': 'https://www.hani.co.kr/arti/1',
        }),
      );
      expect(a.source, ScrapSource.article);
      expect(a.sourceName, 'hani.co.kr');
      expect(a.origin, 'hani.co.kr · 10월 8일');
      expect(a.tags.map((t) => (t.name, t.isNew)), [
        ('아노미', false),
        ('이행기 지연', true),
      ]);
      expect(a.tags[1].similarExisting, ['불안정 노동']);
      expect(a.tags[1].description, '학교에서 일자리로 넘어가는 기간이 길어지는 현상');
      expect(a.draft.containsKey('tags'), isFalse);
      expect(a.draft['content'], '본문');
      // 분석은 오래 걸릴 수 있어 기본(15초)보다 길게 기다린다
      expect(
        server.sentOptions.single.receiveTimeout,
        analyzeOptions.receiveTimeout,
      );
    });

    test('서버 문구(이미 스크랩한 기사, 분석 횟수 초과 등)를 그대로 알린다', () async {
      server.responses['POST /articles/analyze'] = (
        409,
        {'message': '이미 스크랩한 기사입니다.'},
      );

      await expectLater(
        ApiScrapAnalysisRepository(
          server.dio(),
        ).analyzeArticle('https://x.com/a'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            '이미 스크랩한 기사입니다.',
          ),
        ),
      );
    });

    test('책 분석: 사진과 책 정보를 multipart로, 요약이 제목이고 근거 문장·확인 필요를 받는다', () async {
      server.responses['POST /book-scraps/analyze'] = (
        200,
        {
          'bookTitle': '감시와 처벌',
          'author': '미셸 푸코',
          'page': 309,
          'summary': '판옵티콘은 스스로를 규율하게 한다',
          'ocrText': '사진 전문',
          'tags': [
            {
              'tagId': null,
              'name': '판옵티콘',
              'isNew': true,
              'category': '철학',
              'description': '보이지 않는 감시',
              'reason': '정의',
              'explanation': '내면화',
              'similarExisting': <Object>[],
              'excerpt': '언제나 감시당할 수 있다 … 스스로를 감시한다',
              'excerptVerified': true,
            },
            {
              'tagId': 't1',
              'name': '규율 권력',
              'isNew': false,
              'category': '철학',
              'description': null,
              'reason': '훈련',
              'explanation': '',
              'similarExisting': <Object>[],
              'excerpt': '몸을 길들이는 권력',
              'excerptVerified': false,
            },
          ],
        },
      );

      final a = await ApiScrapAnalysisRepository(server.dio()).analyzeBookPage(
        photo: PagePhoto(bytes: Uint8List(5), name: 'IMG_1.jpg'),
        title: '감시와 처벌',
        author: '미셸 푸코',
        page: 309,
      );

      expect(
        server.requests.single,
        req('POST', '/book-scraps/analyze', {
          'bookTitle': '감시와 처벌',
          'author': '미셸 푸코',
          'page': '309',
          'image': 'IMG_1.jpg(5B)',
        }),
      );
      expect(a.source, ScrapSource.book);
      expect(a.title, '판옵티콘은 스스로를 규율하게 한다');
      expect(a.origin, '감시와 처벌 · 미셸 푸코 · 309쪽');
      expect(a.tags.map((t) => (t.excerpt, t.excerptVerified)), [
        ('언제나 감시당할 수 있다 … 스스로를 감시한다', true),
        ('몸을 길들이는 권력', false),
      ]);
      expect(a.draft['summary'], '판옵티콘은 스스로를 규율하게 한다');
    });

    test('책 분석: 저자·쪽수가 없으면 보내지 않는다', () async {
      server.responses['POST /book-scraps/analyze'] = (
        200,
        {'bookTitle': '자살론', 'summary': '요약', 'tags': <Object>[]},
      );

      final a = await ApiScrapAnalysisRepository(server.dio()).analyzeBookPage(
        photo: PagePhoto(bytes: Uint8List(1)),
        title: '자살론',
      );

      expect(
        server.requests.single,
        req('POST', '/book-scraps/analyze', {
          'bookTitle': '자살론',
          'image': 'page.jpg(1B)',
        }),
      );
      expect(a.origin, '자살론');
      expect(
        server.sentOptions.single.receiveTimeout,
        analyzeOptions.receiveTimeout,
      );
    });

    test('책 분석 실패(해상도 부족 등)는 서버 문구로 알린다', () async {
      server.responses['POST /book-scraps/analyze'] = (
        400,
        {'message': '사진 해상도가 너무 낮습니다 (긴 변 1000px 이상). 더 선명하게 다시 찍어주세요.'},
      );

      await expectLater(
        ApiScrapAnalysisRepository(server.dio()).analyzeBookPage(
          photo: PagePhoto(bytes: Uint8List(1)),
          title: '자살론',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('해상도'),
          ),
        ),
      );
    });
  });

  group('ApiScrapRepository', () {
    final article = {
      'id': 'a1',
      'url': 'https://news.example.com/1',
      'title': '배달 라이더 감시',
      'publisher': '경향신문',
      'createdAt': '2026-10-09T03:00:00.000Z',
      'articleTags': [
        {
          'reason': '감시 근거',
          'explanation': '',
          'tag': {'name': '감시사회'},
        },
        {
          'reason': '단절',
          'explanation': '동료와 멀어진다',
          'tag': {'name': '소외'},
        },
      ],
    };
    final book = {
      'id': 'b1',
      'bookTitle': '감시와 처벌',
      'author': '미셸 푸코',
      'page': 309,
      'summary': '판옵티콘은 스스로를 규율하게 한다',
      'createdAt': '2026-10-10T03:00:00.000Z',
      'bookTags': [
        {
          'reason': '정의',
          'explanation': '내면화',
          'excerpt': '언제나 감시당할 수 있다',
          'tag': {'name': '판옵티콘'},
        },
      ],
    };

    test('최근 스크랩: 기사와 책을 합쳐 최근 것부터, 책은 요약이 제목', () async {
      server.responses['GET /articles'] = (200, [article]);
      server.responses['GET /book-scraps'] = (200, [book]);

      final recent = await ApiScrapRepository(server.dio()).fetchRecent();

      expect(recent.map((s) => s.id), ['b1', 'a1']);
      final [b, a] = recent;
      expect(b.title, '판옵티콘은 스스로를 규율하게 한다');
      expect(b.origin, '감시와 처벌 309쪽');
      expect(b.excerpts['판옵티콘'], '언제나 감시당할 수 있다');
      expect(a.conceptNames, ['감시사회', '소외']);
      expect(a.conceptSummary, '감시사회 외 1');
      expect(a.explanations['감시사회'], '감시 근거'); // 풀이가 비면 이유
      expect(a.originDetail, '경향신문 · 10월 9일'); // 발행일이 없으면 저장한 날
    });

    test('기사 출처 줄의 날짜는 발행일을 먼저 쓴다', () {
      final a = ApiScrapRepository.articleFromJson({
        ...article,
        'publishedAt': '2026-07-08T03:00:00.000Z',
      });

      expect(a.originDetail, '경향신문 · 7월 8일');
      expect(a.savedOn, DateTime.parse('2026-10-09T03:00:00.000Z').toLocal());
    });

    test('저장: 분석 원본(draft)에 확인한 태그를 붙여 POST /articles, 응답을 스크랩으로', () async {
      server.responses['POST /articles'] = (201, article);
      const analysis = ScrapAnalysis(
        source: ScrapSource.article,
        title: '배달 라이더 감시',
        origin: '경향신문',
        sourceName: '경향신문',
        tags: [],
        draft: {
          'url': 'https://news.example.com/1',
          'title': '배달 라이더 감시',
          'content': '본문',
        },
      );

      final saved = await ApiScrapRepository(server.dio())
          .save(analysis, const [
            ApprovedTag(name: '감시사회', reason: '감시 근거'),
            ApprovedTag(
              name: '플랫폼 감시',
              reason: '새 개념',
              category: '사회학',
              description: '설명',
            ),
          ]);

      expect(
        server.requests.single,
        req('POST', '/articles', {
          'url': 'https://news.example.com/1',
          'title': '배달 라이더 감시',
          'content': '본문',
          'tags': [
            {'name': '감시사회', 'reason': '감시 근거', 'explanation': ''},
            {
              'name': '플랫폼 감시',
              'reason': '새 개념',
              'explanation': '',
              'category': '사회학',
              'description': '설명',
            },
          ],
        }),
      );
      expect(saved.id, 'a1');
      expect(saved.source, ScrapSource.article);
    });

    test('책 저장은 POST /book-scraps이고 OCR 전문은 돌려보내지 않는다', () async {
      server.responses['POST /book-scraps'] = (201, book);
      const analysis = ScrapAnalysis(
        source: ScrapSource.book,
        title: '요약',
        origin: '감시와 처벌',
        sourceName: '감시와 처벌',
        tags: [],
        draft: {'bookTitle': '감시와 처벌', 'summary': '요약', 'ocrText': '사진 전문'},
      );

      await ApiScrapRepository(server.dio()).save(analysis, const [
        ApprovedTag(name: '판옵티콘', reason: '정의', excerpt: '고친 근거 문장'),
      ]);

      expect(
        server.requests.single,
        req('POST', '/book-scraps', {
          'bookTitle': '감시와 처벌',
          'summary': '요약',
          'tags': [
            {
              'name': '판옵티콘',
              'reason': '정의',
              'explanation': '',
              'excerpt': '고친 근거 문장',
            },
          ],
        }),
      );
    });

    test('저장 실패는 서버 문구로 알린다', () async {
      server.responses['POST /articles'] = (409, {'message': '이미 스크랩한 기사입니다.'});
      const analysis = ScrapAnalysis(
        source: ScrapSource.article,
        title: 't',
        origin: '',
        sourceName: '',
        tags: [],
      );

      await expectLater(
        ApiScrapRepository(
          server.dio(),
        ).save(analysis, const [ApprovedTag(name: 'x', reason: 'r')]),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });
  });
}
