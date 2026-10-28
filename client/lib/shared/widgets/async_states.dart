import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import 'pill_button.dart';

/// 데이터를 불러오는 동안 보여 주는 작은 로딩 표시.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: AppStroke.regular),
      ),
    );
  }
}

/// 불러오기에 실패했을 때 보여 주는 안내와 다시 시도 버튼.
class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('불러오지 못했어요', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xs),
          PillButton(
            label: '다시 시도',
            onPressed: onRetry,
            variant: PillButtonVariant.outlined,
            size: PillButtonSize.small,
          ),
        ],
      ),
    );
  }
}
