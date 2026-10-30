import 'dart:convert';
import 'dart:typed_data';

import 'package:client/shared/data/api_client.dart';
import 'package:client/shared/data/concept_graph_repository.dart';
import 'package:client/shared/data/concept_repository.dart';
import 'package:client/shared/models/concept_graph.dart';
import 'package:client/shared/models/scrap.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 요청 한 건을 비교하기 쉬운 한 줄로 ("PATCH /relations/r1 {"status":"APPROVED"}").
/// 맵은 ==로 내용 비교가 안 되므로 JSON 문자열로 바꿔 비교한다.
String _req(String method, String path, [Object? body]) =>
    '$method $path${body == null ? '' : ' ${jsonEncode(body)}'}';

/// 보낸 요청을 기록하고, "METHOD /path"마다 정해 둔 응답을 돌려주는 가짜 HTTP.
class _FakeServer implements HttpClientAdapter {
  final requests = <String>[];
  final responses = <String, (int, Object?)>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(_req(options.method, options.path, options.data));
    final (status, body) =
        responses['${options.method} ${options.path}'] ?? (204, null);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeServer server;
  late Dio dio;

  setUp(() {
    server = _FakeServer();
    dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = server;
  });

  group('ApiConceptGraphRepository', () {
    test('GET /concepts/graph를 그래프로 바꾼다 (승인=확정, 제안=점선, 관계 id 보관)', () async {
      server.responses['GET /concepts/graph'] = (
        200,
        {
          'nodes': [
            {
              'id': 'a',
              'name': '감시사회',
              'scrapCount': 2,
              'createdAt': '2026-10-29T01:00:00.000Z',
            },
            {
              'id': 'b',
              'name': '판옵티콘',
              'scrapCount': 1,
              'createdAt': '2026-10-28T01:00:00.000Z',
            },
            {
              'id': 'c',
              'name': '소외',
              'scrapCount': 1,
              'createdAt': '2026-10-28T01:00:00.000Z',
            },
          ],
          'links': [
            {
              'id': 'r1',
              'tagAId': 'a',
              'tagBId': 'b',
              'status': 'SUGGESTED',
              'reason': '판옵티콘처럼',
            },
            {
              'id': 'r2',
              'tagAId': 'a',
              'tagBId': 'c',
              'status': 'APPROVED',
              'reason': '같은 기사',
            },
          ],
        },
      );

      final g = await ApiConceptGraphRepository(dio).fetchGraph();

      expect(g.nodes.map((n) => n.name), ['감시사회', '판옵티콘', '소외']);
      expect(g.node('a')!.scrapCount, 2);
      final suggested = g.links.firstWhere((l) => l.id == 'r1');
      expect(suggested.isSuggested, isTrue);
      expect(suggested.reason, '판옵티콘처럼');
      expect(g.links.firstWhere((l) => l.id == 'r2').isSuggested, isFalse);
      expect(g.suggestedLinkCount, 1);
    });

    test('승인·거절(연결 끊기)·되돌리기·이유 수정은 관계 id로 PATCH한다', () async {
      final repo = ApiConceptGraphRepository(dio);
      const suggested = ConceptLink(
        'a',
        'b',
        id: 'r1',
        status: ConceptLinkStatus.suggested,
      );
      const confirmed = ConceptLink('a', 'c', id: 'r2');

      await repo.approveLink(suggested);
      final removed = await repo.removeLink(confirmed);
      await repo.restoreLink(removed!.$1, removed.$2);
      await repo.restoreLink(suggested, 0);
      await repo.updateLinkReason(confirmed, '새 이유');

      expect(server.requests, [
        _req('PATCH', '/relations/r1', {'status': 'APPROVED'}),
        _req('PATCH', '/relations/r2', {
          'status': 'REJECTED',
        }), // 지우지 않고 거절로 남긴다
        _req('PATCH', '/relations/r2', {'status': 'APPROVED'}), // 원래 상태로
        _req('PATCH', '/relations/r1', {'status': 'SUGGESTED'}),
        _req('PATCH', '/relations/r2', {'reason': '새 이유'}),
      ]);
    });

    test('개념 삭제·병합', () async {
      final repo = ApiConceptGraphRepository(dio);

      await repo.deleteConcept('a');
      await repo.mergeConcepts(fromId: 'b', intoId: 'c');

      expect(server.requests, [
        _req('DELETE', '/concepts/a'),
        _req('POST', '/concepts/b/merge', {'intoId': 'c'}),
      ]);
    });

    test('관계 id가 없는 연결은 보낼 수 없고, 서버 오류는 { message }로 알린다', () async {
      final repo = ApiConceptGraphRepository(dio);
      expect(
        () => repo.approveLink(const ConceptLink('a', 'b')),
        throwsStateError,
      );

      server.responses['PATCH /relations/x'] = (
        404,
        {'message': '관계를 찾을 수 없습니다.'},
      );
      await expectLater(
        repo.approveLink(const ConceptLink('a', 'b', id: 'x')),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            '관계를 찾을 수 없습니다.',
          ),
        ),
      );
    });
  });

  group('ApiConceptRepository', () {
    const concept = ConceptNode(id: 't1', name: '판옵티콘');

    test('GET /concepts/:id에서 설명과 스크랩(기사·책, 근거 문장)을 가져온다', () async {
      server.responses['GET /concepts/t1'] = (
        200,
        {
          'description': '보이지 않는 감시 구조',
          'descriptionByAi': false,
          'scraps': [
            {
              'kind': 'article',
              'id': 's1',
              'title': '배달 라이더 감시',
              'source': '경향신문',
              'createdAt': '2026-10-09T03:00:00.000Z',
              'reason': '감시 근거',
              'explanation': '',
            },
            {
              'kind': 'book',
              'id': 's2',
              'title': '판옵티콘은 보이지 않는 시선으로 규율한다',
              'source': '감시와 처벌',
              'author': '미셸 푸코',
              'page': 309,
              'createdAt': '2026-09-29T03:00:00.000Z',
              'reason': '판옵티콘 정의',
              'explanation': '감시가 내면화되는 구조',
              'excerpt': '언제나 감시당할 수 있다',
            },
          ],
        },
      );

      final content = await ApiConceptRepository(dio).fetchContent(concept);

      expect(content.description?.text, '보이지 않는 감시 구조');
      expect(content.description?.byAi, isFalse);
      final [article, book] = content.scraps;
      expect(article.source, ScrapSource.article);
      expect(article.originDetail, '경향신문 · 10월 9일');
      expect(article.explanations['판옵티콘'], '감시 근거'); // 풀이가 비면 이유를 쓴다
      expect(article.excerpts, isEmpty);
      expect(book.source, ScrapSource.book);
      expect(book.title, '판옵티콘은 보이지 않는 시선으로 규율한다'); // 책은 요약이 제목
      expect(book.origin, '감시와 처벌 309쪽');
      expect(book.originDetail, '감시와 처벌 · 미셸 푸코 · 309쪽');
      expect(book.sourceName, '감시와 처벌');
      expect(book.explanations['판옵티콘'], '감시가 내면화되는 구조');
      expect(book.excerpts['판옵티콘'], '언제나 감시당할 수 있다');
    });

    test('설명이 없으면 null, 설명 수정은 PATCH', () async {
      server.responses['GET /concepts/t1'] = (
        200,
        {'description': null, 'descriptionByAi': true, 'scraps': <Object>[]},
      );
      final repo = ApiConceptRepository(dio);

      expect((await repo.fetchContent(concept)).description, isNull);
      await repo.updateDescription('t1', '내가 쓴 설명');

      expect(
        server.requests.last,
        _req('PATCH', '/concepts/t1', {'description': '내가 쓴 설명'}),
      );
    });
  });
}
