import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// 위에 라벨이 붙는 둥근 입력창. 테두리·여백·placeholder 모양은
/// AppTheme의 inputDecorationTheme을 따른다.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.initialValue,
    this.errorText,
    this.trailing,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
  }) : assert(
         controller == null || initialValue == null,
         'controller와 initialValue는 함께 쓸 수 없습니다.',
       );

  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final String? initialValue;
  final String? errorText;

  /// 입력창 오른쪽 끝에 넣을 위젯 (예: 지우기 버튼).
  final Widget? trailing;

  final FocusNode? focusNode;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;

  /// 여러 줄 입력이 필요하면 [maxLines]를 2 이상(또는 null)으로 준다.
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: maxLines,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType:
          keyboardType ?? (maxLines == 1 ? null : TextInputType.multiline),
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      style: AppTypography.body,
      decoration: InputDecoration(
        hintText: hintText,
        // errorText 대신 error 위젯을 넘겨 Figma의 "! + 문구" 모양으로 그린다.
        error: errorText == null ? null : _ErrorMessage(errorText!),
        suffixIcon: trailing,
      ),
    );

    if (label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label!, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.xs),
        field,
      ],
    );
  }
}

/// 입력창 아래 오류 문구 (Figma 입력창 컴포넌트의 "오류" 상태).
class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.black,
              shape: BoxShape.circle,
            ),
            child: Text(
              '!',
              style: AppTypography.buttonSmall.copyWith(
                color: AppColors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text, style: AppTypography.chip)),
        ],
      ),
    );
  }
}
