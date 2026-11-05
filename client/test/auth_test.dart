import 'dart:convert';
import 'dart:typed_data';

import 'package:client/app.dart';
import 'package:client/features/auth/auth_controller.dart';
import 'package:client/features/auth/login_screen.dart';
import 'package:client/features/home/home_screen.dart';
import 'package:client/shared/data/api_client.dart';
import 'package:client/shared/data/auth_repository.dart';
import 'package:client/shared/data/concept_graph_repository.dart';
import 'package:client/shared/data/scrap_repository.dart';
import 'package:client/shared/data/session_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'helpers/signed_in.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('로그인·회원가입 화면', () {
    late FakeAuthRepository auth;
    late MemorySessionStorage storage;

    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      auth = FakeAuthRepository();
      storage = MemorySessionStorage();
      await auth.signup(
        email: 'me@anomie.test',
        password: 'password-1',
        nickname: '나',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            sessionStorageProvider.overrideWithValue(storage),
            scrapRepositoryProvider.overrideWithValue(
              FakeScrapRepository(delay: Duration.zero),
            ),
            conceptGraphRepositoryProvider.overrideWithValue(
              FakeConceptGraphRepository(delay: Duration.zero),
            ),
          ],
          child: const AnomieApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder field(String label) => find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first;

    Future<void> type(WidgetTester tester, String label, String text) =>
        tester.enterText(
          find.descendant(of: field(label), matching: find.byType(TextField)),
          text,
        );

    testWidgets('로그인 전에는 로그인 화면으로 시작한다', (tester) async {
      await pumpApp(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('입력이 비어 있으면 서버에 묻지 않고 안내를 보여 준다', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await tester.pumpAndSettle();

      expect(find.text('이메일을 입력해 주세요'), findsOneWidget);
      expect(find.text('비밀번호를 입력해 주세요'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('틀린 비밀번호면 서버 문구를 보여 주고, 맞으면 홈으로 가며 기기에 로그인을 남긴다', (
      tester,
    ) async {
      await pumpApp(tester);

      await type(tester, '이메일', 'me@anomie.test');
      await type(tester, '비밀번호', 'wrong-pass');
      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await tester.pumpAndSettle();
      expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);

      await type(tester, '비밀번호', 'password-1');
      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect((await storage.read())?.user.nickname, '나');
    });

    testWidgets('회원가입하면 바로 로그인되어 홈으로 간다', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('처음이에요? 회원가입'));
      await tester.pumpAndSettle();

      await type(tester, '이메일', 'new@anomie.test');
      await type(tester, '비밀번호 (8자 이상)', 'short');
      await type(tester, '닉네임', '새 사용자');
      await tester.tap(find.widgetWithText(FilledButton, '가입하기'));
      await tester.pumpAndSettle();
      expect(find.text('비밀번호는 8자 이상이어야 해요'), findsOneWidget);

      await type(tester, '비밀번호 (8자 이상)', 'long-enough-1');
      await tester.tap(find.widgetWithText(FilledButton, '가입하기'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('이미 가입한 이메일이면 서버 문구를 보여 준다', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('처음이에요? 회원가입'));
      await tester.pumpAndSettle();

      await type(tester, '이메일', 'me@anomie.test');
      await type(tester, '비밀번호 (8자 이상)', 'password-2');
      await type(tester, '닉네임', '중복');
      await tester.tap(find.widgetWithText(FilledButton, '가입하기'));
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 이메일입니다.'), findsOneWidget);
    });

    testWidgets('홈 메뉴에서 로그아웃하면 로그인 화면으로 돌아가고 기기의 로그인을 지운다', (tester) async {
      await pumpApp(tester);
      await type(tester, '이메일', 'me@anomie.test');
      await type(tester, '비밀번호', 'password-1');
      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await tester.pumpAndSettle();
      final refreshToken = (await storage.read())!.refreshToken;

      await tester.tap(find.byTooltip('메뉴'));
      await tester.pumpAndSettle();
      expect(find.text('me@anomie.test'), findsOneWidget);
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await storage.read(), isNull);
      expect(
        auth.validRefreshTokens.contains(refreshToken),
        isFalse,
      ); // 서버에도 알렸다
    });
  });

  group('AuthController.refreshTokens', () {
    test('동시에 여러 번 불려도 서버에는 한 번만 묻고, 새 토큰을 저장한다', () async {
      final auth = FakeAuthRepository(delay: const Duration(milliseconds: 10));
      auth.validRefreshTokens.add(testSession.refreshToken);
      final storage = MemorySessionStorage(testSession);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          sessionStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final controller = container.read(authControllerProvider.notifier);
      final results = await Future.wait([
        controller.refreshTokens(),
        controller.refreshTokens(),
      ]);

      expect(auth.refreshCalls, 1);
      expect(results[0]!.accessToken, results[1]!.accessToken);
      expect(results[0]!.refreshToken, isNot(testSession.refreshToken));
      expect((await storage.read())!.refreshToken, results[0]!.refreshToken);
    });

    test('로그인이 만료됐으면(401) 로그아웃 상태가 되고 null', () async {
      final storage = MemorySessionStorage(testSession);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(),
          ), // 유효한 토큰 없음
          sessionStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final result = await container
          .read(authControllerProvider.notifier)
          .refreshTokens();

      expect(result, isNull);
      expect(container.read(authControllerProvider).value, isNull);
      expect(await storage.read(), isNull);
    });
  });

  group('AuthInterceptor', () {
    // 정해 둔 순서대로 응답하고, 받은 Authorization 헤더를 기록하는 가짜 HTTP
    late List<String?> seenAuth;

    ProviderContainer containerWith(
      List<int> statuses,
      FakeAuthRepository auth,
    ) {
      seenAuth = [];
      var i = 0;
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          sessionStorageProvider.overrideWithValue(
            MemorySessionStorage(testSession),
          ),
        ],
      );
      container.read(apiClientProvider).httpClientAdapter = _ScriptedAdapter((
        options,
      ) {
        seenAuth.add(options.headers['Authorization'] as String?);
        return statuses[i++];
      });
      return container;
    }

    test('Access 토큰을 붙이고, 401이면 갱신한 새 토큰으로 한 번 다시 보낸다', () async {
      final auth = FakeAuthRepository()
        ..validRefreshTokens.add(testSession.refreshToken);
      final container = containerWith([401, 200], auth);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final res = await container
          .read(apiClientProvider)
          .get<dynamic>('/concepts');

      expect(res.statusCode, 200);
      expect(seenAuth.first, 'Bearer ${testSession.accessToken}');
      final renewed = container.read(authControllerProvider).value!.accessToken;
      expect(seenAuth.last, 'Bearer $renewed');
      expect(renewed, isNot(testSession.accessToken));
    });

    test('사진 업로드(FormData)도 갱신 뒤 다시 보낼 수 있다', () async {
      final auth = FakeAuthRepository()
        ..validRefreshTokens.add(testSession.refreshToken);
      final container = containerWith([401, 200], auth);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final res = await container
          .read(apiClientProvider)
          .post<dynamic>(
            '/book-scraps/analyze',
            data: FormData.fromMap({
              'bookTitle': '자살론',
              'image': MultipartFile.fromBytes([1, 2, 3], filename: 'p.jpg'),
            }),
          );

      expect(res.statusCode, 200);
      expect(seenAuth, hasLength(2));
    });

    test('갱신도 실패하면 401을 그대로 돌려주고 로그아웃된다', () async {
      final container = containerWith([401], FakeAuthRepository());
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final call = container.read(apiClientProvider).get<dynamic>('/concepts');

      await expectLater(call, throwsA(isA<DioException>()));
      expect(container.read(authControllerProvider).value, isNull);
      expect(seenAuth, hasLength(1)); // 다시 보내지 않았다
    });

    test('일반 요청은 15초, 분석 요청만 90초까지 응답을 기다린다', () {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(apiClientProvider).options.receiveTimeout,
        const Duration(seconds: 15),
      );
      expect(analyzeOptions.receiveTimeout, const Duration(seconds: 90));
    });

    test('서버의 { message }를 ApiException 문구로 바꾼다', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 429,
          data: {'message': '분석 요청이 너무 많습니다.'},
        ),
      );
      final e = ApiException.from(error);
      expect(e.message, '분석 요청이 너무 많습니다.');
      expect(e.statusCode, 429);
      expect(
        ApiException.from(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          ),
        ).message,
        contains('연결할 수 없어요'),
      );
    });

    // 11-05: 배포 빌드에서 "요청을 처리하지 못했어요"만 떠서 원인을 좁힐 수 없었다
    test('분류하지 못한 실패는 상태 코드나 오류 종류를 덧붙인다', () {
      // 문구가 없는 응답 (프록시가 돌려준 빈 502 등)
      expect(
        ApiException.from(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            response: Response(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: 502,
            ),
            type: DioExceptionType.badResponse,
          ),
        ).message,
        '요청을 처리하지 못했어요 (HTTP 502)',
      );
      // 응답 없이 실패 (TLS 오류 등)
      expect(
        ApiException.from(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.unknown,
          ),
        ).message,
        '요청을 처리하지 못했어요 (unknown)',
      );
      // 응답을 해석하다 난 오류 등 Dio 밖의 실패
      expect(
        ApiException.from(TypeError()).message,
        '요청을 처리하지 못했어요 (TypeError)',
      );
    });
  });
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._status);

  final int Function(RequestOptions options) _status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status = _status(options);
    return ResponseBody.fromString(
      jsonEncode(status == 200 ? <String, dynamic>{} : {'message': '인증 실패'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
