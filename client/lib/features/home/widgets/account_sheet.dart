import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/auth_controller.dart';

/// 홈 상단 메뉴(=)를 누르면 열리는 계정 메뉴. 지금은 로그아웃만 있다.
abstract final class AccountSheet {
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authControllerProvider).value?.user;
    final logout = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (user != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.nickname, style: AppTypography.section),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(user.email, style: AppTypography.caption),
                  ],
                ),
              ),
            const Divider(),
            InkWell(
              onTap: () => Navigator.of(context).pop(true),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                  vertical: AppSpacing.md,
                ),
                child: Text('로그아웃', style: AppTypography.bodyStrong),
              ),
            ),
          ],
        ),
      ),
    );
    if (logout != true || !context.mounted) return;

    final confirmed = await showConfirmDialog(
      context,
      title: '로그아웃할까요?',
      message: '이 기기에서 로그아웃해요. 저장한 스크랩과 개념은 그대로 남아요.',
      confirmLabel: '로그아웃',
    );
    if (confirmed) await ref.read(authControllerProvider.notifier).logout();
  }
}
