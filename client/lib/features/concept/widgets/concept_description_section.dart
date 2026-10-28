import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/concept_detail.dart';
import '../../../shared/widgets/label_badge.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/text_link_button.dart';

/// "개념" 설명 + 누가 썼는지 배지 + 수정하기 (Figma 18:43).
class ConceptDescriptionSection extends StatelessWidget {
  const ConceptDescriptionSection({
    super.key,
    required this.description,
    required this.onEdit,
  });

  final ConceptDescription? description;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final d = description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '개념'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          d?.text ?? '아직 설명이 없어요. 수정하기로 직접 써 보세요.',
          style: AppTypography.body,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            if (d != null) ...[
              LabelBadge(d.byAi ? 'AI 생성' : '직접 씀'),
              const SizedBox(width: 10),
            ],
            // 한 번 고친 뒤에도 계속 다듬을 수 있도록 늘 보여 준다.
            TextLinkButton(label: '수정하기', onPressed: onEdit),
          ],
        ),
      ],
    );
  }
}
