import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session.dart';
import 'api_client.dart';

abstract interface class AuthRepository {
  Future<Session> login({required String email, required String password});

  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
  });

  /// Refresh 토큰을 새 토큰 쌍으로 바꾼다. 이전 Refresh 토큰은 더 쓸 수 없다.
  /// 로그인이 만료됐으면 statusCode 401인 [ApiException].
  Future<({String accessToken, String refreshToken})> refresh(
    String refreshToken,
  );

  Future<void> logout(String refreshToken);
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      return res.data ?? const {};
    } catch (e, s) {
      throw ApiException.from(e, s);
    }
  }

  @override
  Future<Session> login({
    required String email,
    required String password,
  }) async => Session.fromJson(
    await _post('/auth/login', {'email': email, 'password': password}),
  );

  @override
  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
  }) => _post('/auth/signup', {
    'email': email,
    'password': password,
    'nickname': nickname,
  });

  @override
  Future<({String accessToken, String refreshToken})> refresh(
    String refreshToken,
  ) async {
    final data = await _post('/auth/refresh', {'refreshToken': refreshToken});
    return (
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  @override
  Future<void> logout(String refreshToken) =>
      _post('/auth/logout', {'refreshToken': refreshToken});
}

/// 테스트용. 메모리에 사용자를 두고 서버와 같은 규칙으로 답한다.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.delay = Duration.zero});

  final Duration delay;

  final _users = <String, ({String password, AuthUser user})>{};
  var _nextToken = 0;

  /// 지금 유효한 Refresh 토큰들. 갱신하면 바뀐다.
  final validRefreshTokens = <String>{};

  int refreshCalls = 0;

  // 지연이 0이면 타이머를 만들지 않는다. testWidgets 본문에서는 pump 전까지 타이머가
  // 돌지 않아, Future.delayed(Duration.zero)를 기다리면 테스트가 끝나지 않는다.
  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  Session _issue(AuthUser user) {
    final refresh = 'refresh-${_nextToken++}';
    validRefreshTokens.add(refresh);
    return Session(
      accessToken: 'access-${_nextToken++}',
      refreshToken: refresh,
      user: user,
    );
  }

  @override
  Future<Session> login({
    required String email,
    required String password,
  }) async {
    await _wait();
    final found = _users[email.trim().toLowerCase()];
    if (found == null || found.password != password) {
      throw const ApiException('이메일 또는 비밀번호가 올바르지 않습니다.', statusCode: 401);
    }
    return _issue(found.user);
  }

  @override
  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
  }) async {
    await _wait();
    final key = email.trim().toLowerCase();
    if (_users.containsKey(key)) {
      throw const ApiException('이미 사용 중인 이메일입니다.', statusCode: 409);
    }
    _users[key] = (
      password: password,
      user: AuthUser(
        id: 'u${_users.length + 1}',
        email: key,
        nickname: nickname,
      ),
    );
  }

  @override
  Future<({String accessToken, String refreshToken})> refresh(
    String refreshToken,
  ) async {
    await _wait();
    refreshCalls++;
    if (!validRefreshTokens.remove(refreshToken)) {
      throw const ApiException('로그인이 만료되었습니다. 다시 로그인해주세요.', statusCode: 401);
    }
    final next = 'refresh-${_nextToken++}';
    validRefreshTokens.add(next);
    return (accessToken: 'access-${_nextToken++}', refreshToken: next);
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _wait();
    validRefreshTokens.remove(refreshToken);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(authDioProvider)),
);
