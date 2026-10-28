import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum PillButtonVariant {
  /// 검정 바탕 + 흰 글자 ("분석하기", "승인").
  filled,

  /// 흰 바탕 + 검정 테두리 ("거절").
  outlined,

  /// 검정 카드 위에 놓이는 흰 바탕 + 검정 글자 ("붙여넣기", "자세히").
  inverted,
}

enum PillButtonSize {
  /// 화면 하단 주요 버튼 (14 SemiBold, 여백 22×16).
  large,

  /// 카드 안 보조 버튼 (13 SemiBold, 여백 18×12: "자세히").
  medium,

  /// 작은 버튼 (12 SemiBold, 여백 16×8: "승인", "붙여넣기").
  small,
}

/// 공통 둥근 버튼. [onPressed]가 null이면 비활성 상태로 그려진다.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PillButtonVariant.filled,
    this.size = PillButtonSize.large,
    this.expand = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillButtonVariant variant;
  final PillButtonSize size;

  /// 가로를 꽉 채울지 여부 (화면 하단의 주요 버튼).
  final bool expand;

  /// true이면 글자 대신 로딩 표시를 보여 주고 누를 수 없다.
  final bool isLoading;

  static void _ignore() {}

  bool get _isLarge => size == PillButtonSize.large;

  ButtonStyle get _sizeStyle => ButtonStyle(
    padding: WidgetStatePropertyAll(switch (size) {
      PillButtonSize.large => const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 16,
      ),
      PillButtonSize.medium => const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      PillButtonSize.small => const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
    }),
    textStyle: WidgetStatePropertyAll(switch (size) {
      PillButtonSize.large => AppTypography.button,
      PillButtonSize.medium => AppTypography.tabSelected,
      PillButtonSize.small => AppTypography.buttonSmall,
    }),
    minimumSize: const WidgetStatePropertyAll(Size.zero),
    tapTargetSize: _isLarge
        ? MaterialTapTargetSize.padded
        : MaterialTapTargetSize.shrinkWrap,
  );

  Color get _foreground => switch (variant) {
    PillButtonVariant.filled => AppColors.white,
    PillButtonVariant.outlined || PillButtonVariant.inverted => AppColors.black,
  };

  @override
  Widget build(BuildContext context) {
    // 로딩 중에는 비활성(25%)처럼 흐려지지 않게 빈 동작을 걸어 둔다.
    final callback = isLoading ? _ignore : onPressed;
    final child = isLoading
        ? SizedBox.square(
            dimension: _isLarge ? 18 : 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: _foreground,
            ),
          )
        : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);

    final Widget button = switch (variant) {
      PillButtonVariant.filled => FilledButton(
        onPressed: callback,
        style: _sizeStyle,
        child: child,
      ),
      PillButtonVariant.outlined => OutlinedButton(
        onPressed: callback,
        style: _sizeStyle,
        child: child,
      ),
      PillButtonVariant.inverted => FilledButton(
        onPressed: callback,
        style: _sizeStyle.merge(
          ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(AppColors.white),
            foregroundColor: const WidgetStatePropertyAll(AppColors.black),
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? AppColors.pressedOnWhite
                  : null,
            ),
          ),
        ),
        child: child,
      ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
