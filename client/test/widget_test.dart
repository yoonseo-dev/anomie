import 'package:client/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    // 테스트에서는 네트워크로 글꼴을 받지 않는다.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('앱이 홈 탭과 하단 메뉴로 시작한다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AnomieApp()));
    await tester.pumpAndSettle();

    expect(find.text('마인드맵'), findsOneWidget);
    expect(find.text('관리'), findsOneWidget);
  });
}
