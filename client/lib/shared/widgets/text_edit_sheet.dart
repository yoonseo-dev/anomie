import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import 'app_text_field.dart';
import 'content_width.dart';
import 'pill_button.dart';

/// 글 한 줄(또는 여러 줄)을 고치는 시트. 저장하면 앞뒤 공백을 뺀 글을 돌려주며 닫힌다.
/// 태그 이름 수정하기, 개념 설명 수정하기에 쓴다.
class TextEditSheet extends StatefulWidget {
  const TextEditSheet({
    super.key,
    required this.title,
    required this.initialText,
    required this.emptyMessage,
    this.hintText,
    this.multiline = false,
  });

  final String title;
  final String initialText;

  /// 비워 둔 채 저장하려 할 때 보여 줄 문구.
  final String emptyMessage;

  final String? hintText;
  final bool multiline;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String initialText,
    required String emptyMessage,
    String? hintText,
    bool multiline = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (_) => TextEditSheet(
        title: title,
        initialText: initialText,
        emptyMessage: emptyMessage,
        hintText: hintText,
        multiline: multiline,
      ),
    );
  }

  @override
  State<TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<TextEditSheet> {
  late final _controller = TextEditingController(text: widget.initialText);
  bool _touched = false;

  bool get _isEmpty => _controller.text.trim().isEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_isEmpty) {
      setState(() => _touched = true);
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 키보드가 올라오면 시트도 함께 올라간다.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.md),
        child: ContentWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: AppTypography.section),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _controller,
                autofocus: true,
                hintText: widget.hintText,
                errorText: _touched && _isEmpty ? widget.emptyMessage : null,
                minLines: widget.multiline ? 4 : null,
                maxLines: widget.multiline ? 8 : 1,
                textInputAction: widget.multiline
                    ? TextInputAction.newline
                    : TextInputAction.done,
                onChanged: (_) => setState(() => _touched = true),
                onSubmitted: widget.multiline ? null : (_) => _save(),
              ),
              const SizedBox(height: AppSpacing.lg),
              PillButton(
                label: '저장',
                expand: true,
                onPressed: _isEmpty ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
