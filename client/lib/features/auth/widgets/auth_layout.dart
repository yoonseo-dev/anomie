import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/corner_marks.dart';

/// 로그인·회원가입 공통 틀: 워드마크 → 제목 → 입력칸 → 오류 문구 → 버튼 → 다른 화면으로 가는 링크.
/// Figma 시안이 없어 홈 상단의 워드마크와 기존 공용 위젯만으로 구성했다.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.fields,
    required this.submit,
    required this.footer,
    this.error,
  });

  final String title;
  final List<Widget> fields;

  /// 서버가 돌려준 오류 (예: "이메일 또는 비밀번호가 올바르지 않습니다.").
  final String? error;

  final Widget submit;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          children: [
            const CornerMarks(),
            const SizedBox(height: AppSpacing.xs),
            Center(child: Text('ANOMIE', style: AppTypography.brandLarge)),
            const SizedBox(height: AppSpacing.xxs),
            Center(child: Text('개념 노트', style: AppTypography.tagline)),
            const SizedBox(height: AppSpacing.sm),
            const CornerMarks(),
            const SizedBox(height: AppSpacing.xxl),
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: AppTypography.headline),
                  const SizedBox(height: AppSpacing.xl),
                  for (final (i, field) in fields.indexed) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    field,
                  ],
                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(error!, style: AppTypography.bodySmall),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  submit,
                  const SizedBox(height: AppSpacing.md),
                  Center(child: footer),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
