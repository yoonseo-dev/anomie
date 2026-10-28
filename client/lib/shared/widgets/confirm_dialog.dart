import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import 'pill_button.dart';

/// 되돌릴 수 없는 작업 전에 묻는 확인 창. 확인을 누르면 true.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTypography.section),
              const SizedBox(height: AppSpacing.sm),
              Text(message, style: AppTypography.bodySmall),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PillButton(
                    label: '취소',
                    onPressed: () => Navigator.of(context).pop(false),
                    variant: PillButtonVariant.outlined,
                    size: PillButtonSize.small,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  PillButton(
                    label: confirmLabel,
                    onPressed: () => Navigator.of(context).pop(true),
                    size: PillButtonSize.small,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}
