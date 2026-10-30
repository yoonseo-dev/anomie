import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 요청 한 건을 비교하기 쉬운 한 줄로 ("PATCH /relations/r1 {"status":"APPROVED"}").
/// 맵은 ==로 내용 비교가 안 되므로 JSON 문자열로 바꿔 비교한다.
/// 업로드(FormData)는 필드와 "파일 이름(바이트 수)"로 적는다.
String req(String method, String path, [Object? body]) =>
    '$method $path${body == null ? '' : ' ${jsonEncode(_plain(body))}'}';

Object? _plain(Object body) => switch (body) {
  FormData f => {
    for (final e in f.fields) e.key: e.value,
    for (final e in f.files) e.key: '${e.value.filename}(${e.value.length}B)',
  },
  _ => body,
};

/// Api 저장소 테스트용 가짜 HTTP. 보낸 요청을 [requests]에 기록하고,
/// "METHOD /path"마다 [responses]에 정해 둔 (상태 코드, 본문)을 돌려준다. 없으면 204.
class FakeServer implements HttpClientAdapter {
  final requests = <String>[];
  final responses = <String, (int, Object?)>{};

  /// 이 서버로 요청을 보내는 Dio.
  Dio dio() =>
      Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = this;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(req(options.method, options.path, options.data));
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
