import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'pill_bottom_nav.dart';

/// 하단 메뉴가 있는 탭 화면의 공통 틀.
/// 탭 화면은 스크롤 끝에 [AppSpacing.bottomNavClearance]만큼 여백을 두어야 한다.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _labels = ['홈', '마인드맵', '관리'];

  /// 하단 메뉴 뒤 흰색 그라데이션 높이 (Figma 14:108).
  static const double fadeHeight = 90;

  /// 화면 아래 안전 영역 위로 하단 메뉴를 띄우는 간격.
  static const double _navBottomGap = AppSpacing.md;

  /// 하단 메뉴 위에 떠 있어야 하는 내용(마인드맵의 개념 카드 등)이
  /// 화면 아래에서 비워 둘 높이. 그라데이션에 덮이지 않게 그 위에 놓는다.
  static double floatingContentInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + fadeHeight;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      // 이미 선택된 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          // 아래로 스크롤된 내용이 메뉴 뒤에서 흐려지게 하는 흰색 그라데이션.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.whiteClear, AppColors.white],
                    stops: [0, 0.45],
                  ),
                ),
                child: SizedBox(
                  height: floatingContentInset(context),
                  width: double.infinity,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: _navBottomGap),
              child: Center(
                child: PillBottomNav(
                  labels: _labels,
                  currentIndex: navigationShell.currentIndex,
                  onTap: _onTap,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
