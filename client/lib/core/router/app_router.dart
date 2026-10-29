import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/concept/concept_detail_screen.dart';
import '../../features/dev/widget_gallery_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/manage/manage_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/scrap/new_scrap_screen.dart';
import '../../features/scrap/tag_review_screen.dart';
import '../../shared/models/scrap.dart';
import '../../shared/models/session.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/async_states.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  // 로그인 상태가 바뀌면 redirect를 다시 계산한다 (로그인 → 홈, 로그아웃·만료 → 로그인).
  final auth = ValueNotifier<AsyncValue<Session?>>(
    ref.read(authControllerProvider),
  );
  ref
    ..listen(authControllerProvider, (_, next) => auth.value = next)
    ..onDispose(auth.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: auth,
    redirect: (context, state) => _guard(auth.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const Scaffold(body: LoadingIndicator()),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),

      // 하단 메뉴가 있는 탭 3개. 탭마다 자기 이동 기록을 따로 유지한다.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.manage,
                builder: (context, state) => ManageScreen(
                  initialTab: ManageTab.fromQuery(
                    state.uri.queryParameters['tab'],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      // 하단 메뉴 없이 탭 위로 덮는 화면들. 루트 Navigator에 올라간다.
      GoRoute(
        path: AppRoutes.scrapNew,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _coverPage(
          state,
          NewScrapScreen(
            initialSource: ScrapSource.fromQuery(
              state.uri.queryParameters['type'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.tagReview,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _coverPage(state, const TagReviewScreen()),
      ),
      GoRoute(
        path: AppRoutes.conceptDetail,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _coverPage(
          state,
          ConceptDetailScreen(conceptId: state.pathParameters['id']!),
        ),
      ),

      if (kDebugMode)
        GoRoute(
          path: AppRoutes.widgetGallery,
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const WidgetGalleryScreen(),
        ),
    ],
  );
});

/// 인증 가드. 저장된 로그인을 읽는 중이면 시작 화면, 로그아웃 상태면 로그인 화면,
/// 로그인 상태에서 로그인·시작 화면에 있으면 홈으로 보낸다.
String? _guard(AsyncValue<Session?> auth, String location) {
  final onAuthPage =
      location == AppRoutes.login || location == AppRoutes.signup;
  if (!auth.hasValue && !auth.hasError) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }
  final signedIn = auth.value != null;
  if (!signedIn) return onAuthPage ? null : AppRoutes.login;
  if (onAuthPage || location == AppRoutes.splash) return AppRoutes.home;
  return null;
}

/// 아래에서 위로 올라와 덮는 전환.
CustomTransitionPage<void> _coverPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    fullscreenDialog: true,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
