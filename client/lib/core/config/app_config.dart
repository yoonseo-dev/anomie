import 'package:flutter/foundation.dart';

/// 실행 환경 설정. 서버 주소는 빌드할 때 바꿀 수 있다:
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`
abstract final class AppConfig {
  static const _apiBaseUrlFromEnv = String.fromEnvironment('API_BASE_URL');

  /// 따로 주지 않으면 개발용 로컬 서버(포트 3000).
  /// 안드로이드 에뮬레이터에서는 PC의 localhost가 10.0.2.2로 보인다.
  static String get apiBaseUrl {
    if (_apiBaseUrlFromEnv.isNotEmpty) return _apiBaseUrlFromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }
}
