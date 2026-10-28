import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 클립보드에서 기사 주소를 읽는다.
///
/// 실제 구현은 `Clipboard.getData`를 쓰면 되지만, iOS는 읽을 때마다 붙여넣기
/// 허용 창을 띄우므로 언제 읽을지 정한 뒤에 바꾼다.
abstract interface class ClipboardSource {
  Future<String?> readText();
}

/// 서버·기기 연결 전까지 쓰는 가짜 클립보드 (Figma 16:245).
class FakeClipboardSource implements ClipboardSource {
  const FakeClipboardSource([
    this.text = 'https://hani.co.kr/arti/society/1162',
  ]);

  final String? text;

  @override
  Future<String?> readText() async => text;
}

final clipboardSourceProvider = Provider<ClipboardSource>(
  (ref) => const FakeClipboardSource(),
);

final clipboardTextProvider = FutureProvider.autoDispose<String?>(
  (ref) => ref.watch(clipboardSourceProvider).readText(),
);
