import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/concept/concept_detail_screen.dart';
import '../../features/dev/widget_gallery_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/manage/manage_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/scrap/new_scrap_screen.dart';
import '../../features/scrap/tag_review_screen.dart';
import '../../shared/models/scrap.dart';
import '../../shared/widgets/app_shell.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: kDebugMode,
    routes: [
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
