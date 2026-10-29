import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';

/// 로그인 상태를 기기에 보관한다. 앱을 다시 켜도 로그인이 유지된다.
abstract interface class SessionStorage {
  Future<Session?> read();

  Future<void> write(Session session);

  Future<void> clear();
}

/// 토큰은 평문 저장소(SharedPreferences)가 아니라 기기의 보안 저장소(키체인·키스토어)에 둔다.
class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'session';

  final FlutterSecureStorage _storage;

  @override
  Future<Session?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // 형식이 바뀐 옛 값이면 버리고 다시 로그인하게 한다.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(Session session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// 테스트용. 메모리에만 보관한다.
class MemorySessionStorage implements SessionStorage {
  MemorySessionStorage([this._session]);

  Session? _session;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SecureSessionStorage(),
);
