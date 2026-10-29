import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/api_client.dart';
import '../../shared/data/auth_repository.dart';
import '../../shared/data/session_storage.dart';
import '../../shared/models/session.dart';

/// 로그인 상태. 불러오는 중(기기 저장소 읽기) → 로그인됨(Session) / 로그아웃됨(null).
/// 라우터가 이 값을 보고 로그인 화면과 앱 화면을 오간다.
class AuthController extends AsyncNotifier<Session?> {
  Future<Session?>? _refreshing;

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  SessionStorage get _storage => ref.read(sessionStorageProvider);

  @override
  Future<Session?> build() => _storage.read();

  Future<void> _signIn(Session session) async {
    await _storage.write(session);
    state = AsyncData(session);
  }

  /// 실패하면 [ApiException]을 던진다 (화면이 문구를 보여 준다).
  Future<void> login({required String email, required String password}) async {
    await _signIn(await _repo.login(email: email.trim(), password: password));
  }

  /// 가입하고 바로 로그인한다.
  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
  }) async {
    await _repo.signup(
      email: email.trim(),
      password: password,
      nickname: nickname.trim(),
    );
    await login(email: email, password: password);
  }

  /// 서버에 알리지 못해도(오프라인 등) 기기에서는 로그아웃한다.
  Future<void> logout() async {
    final session = state.value;
    await _storage.clear();
    state = const AsyncData(null);
    if (session != null) {
      try {
        await _repo.logout(session.refreshToken);
      } on Object {
        // Refresh 토큰은 30일 뒤 서버에서 저절로 만료된다.
      }
    }
  }

  /// Access 토큰이 만료됐을 때 [AuthInterceptor]가 부른다. 새 세션을 돌려주고,
  /// 로그인이 만료됐으면(401) 로그아웃하고 null. 동시에 여러 번 불려도 서버에는 한 번만 묻는다
  /// (서버는 Refresh 토큰을 한 번만 받아 주고, 같은 토큰이 두 번 오면 탈취로 본다).
  Future<Session?> refreshTokens() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<Session?> _refresh() async {
    final session = state.value;
    if (session == null) return null;
    try {
      final tokens = await _repo.refresh(session.refreshToken);
      final next = session.withTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      await _signIn(next);
      return next;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _storage.clear();
        state = const AsyncData(null);
      }
      // 네트워크 오류 등은 로그인을 유지하고 이번 요청만 실패시킨다.
      return null;
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, Session?>(
  AuthController.new,
);
