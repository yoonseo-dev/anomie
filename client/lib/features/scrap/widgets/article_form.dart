import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/data/clipboard_source.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../scrap_validators.dart';
import 'clipboard_url_card.dart';

/// 기사 모드 입력 (Figma 16:225).
class ArticleForm extends ConsumerWidget {
  const ArticleForm({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.onChanged,
    required this.onSubmitted,
    required this.onPaste,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onPaste;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipboard = ref.watch(clipboardTextProvider).value;
    // 클립보드에 기사 주소가 있고, 아직 입력창에 넣지 않았을 때만 카드를 보여 준다.
    final showClipboard =
        clipboard != null &&
        ScrapValidators.articleUrl(clipboard) == null &&
        clipboard.trim() != controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text('어떤 기사를\n스크랩할까요', style: AppTypography.headline),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          label: '기사 주소',
          hintText: 'https://',
          controller: controller,
          focusNode: focusNode,
          errorText: errorText,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
        if (showClipboard) ...[
          const SizedBox(height: AppSpacing.xl),
          ClipboardUrlCard(
            url: clipboard,
            onPaste: () => onPaste(clipboard.trim()),
          ),
        ],
      ],
    );
  }
}
