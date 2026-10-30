import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../features/auth/auth_controller.dart';

/// 서버 오류를 화면에 보여 줄 문구로 정리한 것. 서버는 `{ message }`로 답한다.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final data = error.response?.data;
      final serverMessage = data is Map ? data['message'] : null;
      if (serverMessage is String && serverMessage.isNotEmpty) {
        return ApiException(
          serverMessage,
          statusCode: error.response?.statusCode,
        );
      }
      return switch (error.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout => const ApiException(
          '서버에 연결할 수 없어요. 인터넷 연결을 확인해 주세요',
        ),
        DioExceptionType.receiveTimeout || DioExceptionType.sendTimeout =>
          const ApiException('응답이 늦어지고 있어요. 잠시 뒤 다시 시도해 주세요'),
        _ => ApiException(
          '요청을 처리하지 못했어요',
          statusCode: error.response?.statusCode,
        ),
      };
    }
    return const ApiException('요청을 처리하지 못했어요');
  }

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

BaseOptions _baseOptions() => BaseOptions(
  baseUrl: AppConfig.apiBaseUrl,
  connectTimeout: const Duration(seconds: 10),
  // 분석(크롤링·OCR·Claude)은 수십 초 걸릴 수 있다.
  receiveTimeout: const Duration(seconds: 90),
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
    final session = await _auth.refreshTokens();
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
