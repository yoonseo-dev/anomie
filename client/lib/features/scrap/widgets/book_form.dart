import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/scrap_analysis.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'page_photo_card.dart';

/// 책 모드 입력 (Figma 16:278).
class BookForm extends StatelessWidget {
  const BookForm({
    super.key,
    required this.photo,
    required this.onCapture,
    required this.titleController,
    required this.titleFocusNode,
    required this.authorController,
    required this.pageController,
    required this.titleError,
    required this.pageError,
    required this.onTitleChanged,
    required this.onAuthorChanged,
    required this.onPageChanged,
  });

  final PagePhoto? photo;
  final VoidCallback onCapture;

  final TextEditingController titleController;
  final FocusNode titleFocusNode;
  final TextEditingController authorController;
  final TextEditingController pageController;

  final String? titleError;
  final String? pageError;

  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onAuthorChanged;
  final ValueChanged<String> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        PagePhotoCard(photo: photo, onCapture: onCapture),
        const SizedBox(height: 10),
        Text('사진은 분석 후 바로 지워집니다', style: AppTypography.caption),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          label: '책 제목',
          hintText: '예: 자살론',
          controller: titleController,
          focusNode: titleFocusNode,
          errorText: titleError,
          textInputAction: TextInputAction.next,
          onChanged: onTitleChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: AppTextField(
                label: '저자 (선택)',
                hintText: '예: 에밀 뒤르켐',
                controller: authorController,
                textInputAction: TextInputAction.next,
                onChanged: onAuthorChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppTextField(
                label: '페이지',
                hintText: '쪽',
                controller: pageController,
                errorText: pageError,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onChanged: onPageChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
