import 'package:client/shared/data/session_storage.dart';
import 'package:client/shared/models/session.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

const testUser = AuthUser(id: 'u1', email: 'me@anomie.test', nickname: '테스터');

const testSession = Session(
  accessToken: 'access-test',
  refreshToken: 'refresh-test',
  user: testUser,
);

/// 앱 전체를 띄우는 테스트는 로그인된 상태로 시작한다 (인증 가드가 로그인 화면으로 보내지 않게).
/// 기기 보안 저장소 대신 메모리 저장소를 쓴다.
List<Override> signedIn([Session session = testSession]) => [
  sessionStorageProvider.overrideWithValue(MemorySessionStorage(session)),
];
