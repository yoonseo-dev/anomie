import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  /// fromSeed를 쓰지 않고 모든 역할을 검정/흰색으로 직접 지정한다.
  /// Material 3가 자동으로 섞는 틴트·컨테이너 색이 끼어들지 않게 하기 위해서다.
  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.black,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.black,
    onPrimaryContainer: AppColors.white,
    secondary: AppColors.black,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.white,
    onSecondaryContainer: AppColors.black,
    tertiary: AppColors.black,
    onTertiary: AppColors.white,
    error: AppColors.black,
    onError: AppColors.white,
    errorContainer: AppColors.white,
    onErrorContainer: AppColors.black,
    surface: AppColors.white,
    onSurface: AppColors.black,
    onSurfaceVariant: AppColors.black,
    surfaceDim: AppColors.white,
    surfaceBright: AppColors.white,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.white,
    surfaceContainer: AppColors.white,
    surfaceContainerHigh: AppColors.white,
    surfaceContainerHighest: AppColors.white,
    surfaceTint: AppColors.white,
    outline: AppColors.black,
    outlineVariant: AppColors.divider,
    inverseSurface: AppColors.black,
    onInverseSurface: AppColors.white,
    inversePrimary: AppColors.white,
    shadow: AppColors.black,
    scrim: AppColors.black,
  );

  static const StadiumBorder _pill = StadiumBorder();

  static WidgetStateProperty<Color?> _overlay(Color color) =>
      WidgetStateProperty.resolveWith(
        (states) =>
            states.any(
              const {
                WidgetState.pressed,
                WidgetState.hovered,
                WidgetState.focused,
              }.contains,
            )
            ? color
            : null,
      );

  static OutlineInputBorder _inputBorder(double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.input),
    borderSide: BorderSide(color: AppColors.black, width: width),
  );

  static ThemeData get light {
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: AppColors.white,
      canvasColor: AppColors.white,
      dividerColor: AppColors.black,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // 눌림 효과도 흑백으로.
      splashFactory: InkRipple.splashFactory,
      splashColor: AppColors.pressedOnWhite,
      highlightColor: AppColors.pressedOnWhite,
      hoverColor: AppColors.pressedOnWhite,
      focusColor: AppColors.pressedOnWhite,

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.black,
        selectionColor: AppColors.divider,
        selectionHandleColor: AppColors.black,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.appBarTitle,
        iconTheme: const IconThemeData(color: AppColors.black, size: 22),
      ),

      iconTheme: const IconThemeData(color: AppColors.black, size: 22),

      dividerTheme: const DividerThemeData(
        color: AppColors.black,
        thickness: AppStroke.hairline,
        space: AppStroke.hairline,
      ),

      // 큰 버튼 기본값. 작은 버튼·반전 버튼은 PillButton에서 덮어쓴다.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(_pill),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          ),
          textStyle: WidgetStatePropertyAll(AppTypography.button),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.disabled
                : AppColors.black,
          ),
          foregroundColor: const WidgetStatePropertyAll(AppColors.white),
          overlayColor: _overlay(AppColors.pressedOnBlack),
          surfaceTintColor: const WidgetStatePropertyAll(AppColors.white),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(_pill),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          ),
          textStyle: WidgetStatePropertyAll(AppTypography.button),
          backgroundColor: const WidgetStatePropertyAll(AppColors.white),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.disabled
                : AppColors.black,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? AppColors.disabled
                  : AppColors.black,
              width: AppStroke.hairline,
            ),
          ),
          overlayColor: _overlay(AppColors.pressedOnWhite),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(AppColors.black),
          textStyle: WidgetStatePropertyAll(AppTypography.chip),
          overlayColor: _overlay(AppColors.pressedOnWhite),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(AppColors.black),
          overlayColor: _overlay(AppColors.pressedOnWhite),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: AppTypography.body.copyWith(color: AppColors.hint),
        errorStyle: AppTypography.caption,
        border: _inputBorder(AppStroke.hairline),
        enabledBorder: _inputBorder(AppStroke.hairline),
        focusedBorder: _inputBorder(AppStroke.regular),
        // 흑백이라 오류는 2px 테두리와 ! 아이콘으로 구분한다 (Figma 입력창 컴포넌트).
        errorBorder: _inputBorder(AppStroke.strong),
        focusedErrorBorder: _inputBorder(AppStroke.strong),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.disabled),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.black,
        disabledColor: AppColors.white,
        labelStyle: AppTypography.chip,
        secondaryLabelStyle: AppTypography.chip.copyWith(
          color: AppColors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        shape: const StadiumBorder(side: BorderSide(color: AppColors.black)),
        surfaceTintColor: AppColors.white,
        elevation: 0,
        pressElevation: 0,
        showCheckmark: false,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.black,
        contentTextStyle: AppTypography.body.copyWith(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.black,
        linearTrackColor: AppColors.divider,
        circularTrackColor: AppColors.divider,
      ),
    );
  }
}
