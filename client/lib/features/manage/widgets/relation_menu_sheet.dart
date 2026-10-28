import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';

enum RelationMenuAction { edit, unlink }

/// 연결됨 줄의 ··· 메뉴. 고른 동작을 돌려주며 닫힌다.
abstract final class RelationMenuSheet {
  static Future<RelationMenuAction?> show(
    BuildContext context, {
    required String title,
  }) {
    return showModalBottomSheet<RelationMenuAction>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) {
        Widget item(String label, RelationMenuAction action) => InkWell(
          onTap: () => Navigator.of(context).pop(action),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.md,
            ),
            child: Text(label, style: AppTypography.bodyStrong),
          ),
        );

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.sm,
                ),
                child: Text(title, style: AppTypography.section),
              ),
              const Divider(),
              item('수정하기', RelationMenuAction.edit),
              const Divider(),
              item('연결 끊기', RelationMenuAction.unlink),
            ],
          ),
        );
      },
    );
  }
}
