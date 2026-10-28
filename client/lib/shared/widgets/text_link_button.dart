import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// 밑줄 글자 버튼 ("이름 수정하기", "빼기", "수정하기").
class TextLinkButton extends StatelessWidget {
  const TextLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 11px 작은 글자 ("제안 확인하기").
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      excludeSemantics: true,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: Padding(
          // 글자는 작아도 누르기 쉽도록 위아래로 자리를 조금 더 잡는다.
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Text(
            label,
            style: small ? AppTypography.linkSmall : AppTypography.link,
          ),
        ),
      ),
    );
  }
}
