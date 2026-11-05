import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../features/auth/auth_controller.dart';
import '../models/session.dart';

/// 서버 오류를 화면에 보여 줄 문구로 정리한 것. 서버는 `{ message }`로 답한다.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  factory ApiException.from(Object error, [StackTrace? stack]) {
    if (error is ApiException) return error;
    // 원인을 알 수 있게 실제 오류를 기기 로그(logcat의 flutter 태그)에 남긴다. 배포용 빌드에서도 찍힌다.
    debugPrint('[API] 실패: $error');
    if (stack != null) debugPrint('$stack');
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      final serverMessage = data is Map ? data['message'] : null;
      if (serverMessage is String && serverMessage.isNotEmpty) {
        return ApiException(serverMessage, statusCode: status);
      }
      return switch (error.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout => const ApiException(
          '서버에 연결할 수 없어요. 인터넷 연결을 확인해 주세요',
        ),
        DioExceptionType.receiveTimeout || DioExceptionType.sendTimeout =>
          const ApiException('응답이 늦어지고 있어요. 잠시 뒤 다시 시도해 주세요'),
        // 분류하지 못한 실패는 상태 코드나 오류 종류를 덧붙여 화면만 보고도 원인을 좁힐 수 있게 한다 (11-05)
        _ => ApiException(
          '요청을 처리하지 못했어요 (${status != null ? 'HTTP $status' : error.type.name})',
          statusCode: status,
        ),
      };
    }
    return ApiException('요청을 처리하지 못했어요 (${error.runtimeType})');
  }

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 목록·상세·저장처럼 금방 끝나는 요청의 응답 대기 시간. 연결이 응답 없이 멈추면
/// (예: 무선 디버깅 재연결 뒤 끊긴 adb reverse) 로딩만 도는 대신 "다시 시도"를 보여 준다.
const defaultReceiveTimeout = Duration(seconds: 15);

/// 분석(크롤링·OCR·Claude)은 수십 초 걸릴 수 있어 이 요청에만 길게 준다.
final analyzeOptions = Options(receiveTimeout: const Duration(seconds: 90));

BaseOptions _baseOptions() => BaseOptions(
  baseUrl: AppConfig.apiBaseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: defaultReceiveTimeout,
  contentType: Headers.jsonContentType,
);

/// 로그인·토큰 갱신용. 토큰을 붙이지 않는다 (갱신 중에 다시 갱신하는 고리를 막는다).
final authDioProvider = Provider<Dio>((ref) => Dio(_baseOptions()));

/// 그 밖의 모든 API용. Access 토큰을 붙이고, 401이면 한 번 갱신한 뒤 다시 보낸다.
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(AuthInterceptor(ref, dio));
  return dio;
});

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref, this._dio);

  final Ref _ref;
  final Dio _dio;

  static const _retried = 'authRetried';

  AuthController get _auth => _ref.read(authControllerProvider.notifier);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _ref.read(authControllerProvider).value?.accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || options.extra[_retried] == true) {
      return handler.next(err);
    }

    // Access 토큰이 만료됐다. 여러 요청이 동시에 401을 받아도 갱신은 한 번만 한다.
    final Session? session;
    try {
      session = await _auth.refreshTokens();
    } catch (e, s) {
      // 예상하지 못한 이유로 갱신하지 못했다. 그대로 두면 로그인된 것처럼 보이는데 모든 요청이 실패하는
      // 상태에 갇힌다 (11-05 배포 앱: 갱신 요청이 아예 나가지 않음, doc/troubleshooting.md 23번).
      // 원인을 기기 로그에 남기고 로그아웃해서 다시 로그인하게 한다.
      debugPrint('[API] 토큰 갱신 중 예상하지 못한 오류: $e\n$s');
      try {
        await _auth.logout();
      } catch (_) {}
      return handler.next(err);
    }
    if (session == null) {
      // 로그인이 풀렸다 → 라우터가 로그인 화면으로 보낸다
      return handler.next(err);
    }

    try {
      options.extra[_retried] = true;
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      // 사진 업로드(FormData)는 한 번 보내면 다시 쓸 수 없어 복제해서 보낸다.
      if (options.data case final FormData form) options.data = form.clone();
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
