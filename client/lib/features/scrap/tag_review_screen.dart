import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/corner_marks.dart';
import '../../shared/widgets/pill_button.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/text_edit_sheet.dart';
import 'tag_review_controller.dart';
import 'widgets/source_summary_card.dart';
import 'widgets/suggested_tag_card.dart';

/// 태그 확인 (Figma 17:15). 새 스크랩 화면 위에 열리고, ‹로 돌아가면 입력을 고칠 수 있다.
class TagReviewScreen extends ConsumerWidget {
  const TagReviewScreen({super.key});

  Future<void> _rename(
    BuildContext context,
    TagReviewController controller,
    int index,
    String current,
  ) async {
    final name = await TextEditSheet.show(
      context,
      title: '태그 이름 수정하기',
      initialText: current,
      hintText: '예: 아노미',
      emptyMessage: TagReviewController.renameEmptyMessage,
    );
    if (name != null) controller.rename(index, name);
  }

  void _remove(
    BuildContext context,
    TagReviewController controller,
    int index,
    String name,
  ) {
    controller.remove(index);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$name 태그를 뺐어요'),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () => controller.restore(index),
          ),
        ),
      );
  }

  Future<void> _save(
    BuildContext context,
    TagReviewController controller,
  ) async {
    // 홈으로 옮긴 뒤에도 안내가 보이도록 앱 전체의 메신저를 먼저 잡아 둔다.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final ok = await controller.save();
      if (!ok) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('스크랩을 저장했어요')));
      // 새 스크랩·태그 확인 화면을 모두 닫고 홈으로 간다.
      router.go(AppRoutes.home);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('저장하지 못했어요. 잠시 뒤 다시 시도해 주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tagReviewControllerProvider);
    final controller = ref.read(tagReviewControllerProvider.notifier);
    final analysis = state.analysis;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, size: 28),
        ),
        title: const Text('태그 확인'),
      ),
      body: analysis == null
          ? _Empty(onBack: () => context.pop())
          : Column(
              children: [
                const CornerMarks(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.xl,
                    ),
                    child: ContentWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SourceSummaryCard(analysis: analysis),
                          const SizedBox(height: AppSpacing.xxl),
                          SectionHeader(
                            title: '찾은 개념',
                            count: '${state.keptCount}',
                            large: true,
                          ),
                          for (final (i, draft) in state.drafts.indexed)
                            if (!draft.removed) ...[
                              const SizedBox(height: AppSpacing.sm),
                              SuggestedTagCard(
                                key: ValueKey(i),
                                draft: draft,
                                onReplace: (name) =>
                                    controller.toggleReplacement(i, name),
                                onRename: () => _rename(
                                  context,
                                  controller,
                                  i,
                                  draft.finalName,
                                ),
                                onRemove: () => _remove(
                                  context,
                                  controller,
                                  i,
                                  draft.finalName,
                                ),
                              ),
                            ],
                          if (state.keptCount == 0)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.lg,
                              ),
                              child: Text(
                                '남은 태그가 없어요. 빼기를 되돌리거나 ‹로 돌아가 다시 분석해 주세요.',
                                style: AppTypography.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: ContentWidth(
                      child: PillButton(
                        label: '태그 ${state.keptCount}개 저장',
                        expand: true,
                        isLoading: state.isSaving,
                        onPressed: state.canSave
                            ? () => _save(context, controller)
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('확인할 태그가 없어요', style: AppTypography.body),
          const SizedBox(height: AppSpacing.md),
          PillButton(
            label: '돌아가기',
            onPressed: onBack,
            variant: PillButtonVariant.outlined,
            size: PillButtonSize.small,
          ),
        ],
      ),
    );
  }
}
