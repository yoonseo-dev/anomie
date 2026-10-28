import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/data/concept_detail_provider.dart';
import '../../shared/data/concept_repository.dart';
import '../../shared/models/concept_detail.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/corner_marks.dart';
import '../../shared/widgets/pill_button.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/text_edit_sheet.dart';
import '../map/map_controller.dart';
import 'widgets/concept_description_section.dart';
import 'widgets/concept_graph_card.dart';
import 'widgets/concept_scrap_entry.dart';
import 'widgets/linked_concept_row.dart';

/// 태그(개념) 상세 (Figma 18:12). 하단 메뉴 없이 위로 덮는 화면이다.
class ConceptDetailScreen extends ConsumerWidget {
  const ConceptDetailScreen({super.key, required this.conceptId});

  final String conceptId;

  /// 마인드맵 탭으로 가서 이 개념을 가운데에 둔다.
  void _openInMap(BuildContext context, WidgetRef ref) {
    ref.read(mapTrailProvider.notifier).focus(conceptId);
    context.go(AppRoutes.map);
  }

  Future<void> _editDescription(
    BuildContext context,
    WidgetRef ref,
    ConceptDetail detail,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await TextEditSheet.show(
      context,
      title: '개념 설명 수정하기',
      initialText: detail.description?.text ?? '',
      emptyMessage: '설명을 넣어 주세요',
      multiline: true,
    );
    if (text == null) return;
    try {
      await ref
          .read(conceptRepositoryProvider)
          .updateDescription(conceptId, text);
      ref.invalidate(conceptDetailProvider(conceptId));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('저장하지 못했어요. 잠시 뒤 다시 시도해 주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(conceptDetailProvider(conceptId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, size: 28),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton(
              onPressed: () => _openInMap(context, ref),
              child: const Text('마인드맵'),
            ),
          ),
        ],
      ),
      body: detail.when(
        // 수정 후 다시 불러오는 동안에는 이전 내용을 그대로 보여 준다.
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        data: (d) => d == null
            ? _NotFound(onBack: () => context.pop())
            : _DetailBody(
                detail: d,
                onOpenMap: () => _openInMap(context, ref),
                onEditDescription: () => _editDescription(context, ref, d),
              ),
        loading: () => const LoadingIndicator(),
        error: (_, _) => Center(
          child: LoadError(
            onRetry: () => ref.invalidate(conceptDetailProvider(conceptId)),
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.onOpenMap,
    required this.onEditDescription,
  });

  final ConceptDetail detail;
  final VoidCallback onOpenMap;
  final VoidCallback onEditDescription;

  @override
  Widget build(BuildContext context) {
    final concept = detail.concept;
    final first = detail.firstScrap;
    final linkCount = detail.suggestedCount == 0
        ? '${detail.confirmedCount}'
        : '${detail.confirmedCount} + 제안 ${detail.suggestedCount}';

    return ListView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 48,
      ),
      children: [
        const CornerMarks(),
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Text(concept.name, style: AppTypography.displayTitle),
              const SizedBox(height: 6),
              Text(
                '스크랩 ${detail.scraps.length}   '
                '연결 ${detail.confirmedCount}   '
                '제안 ${detail.suggestedCount}',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.lg),
              ConceptGraphCard(
                graph: detail.graph,
                conceptId: concept.id,
                onTap: onOpenMap,
              ),
              const SizedBox(height: 28),
              ConceptDescriptionSection(
                description: detail.description,
                onEdit: onEditDescription,
              ),
              const SizedBox(height: 36),
              SectionHeader(title: '내 스크랩에서', count: '${detail.scraps.length}'),
              const SizedBox(height: AppSpacing.sm),
              if (detail.scraps.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    '아직 이 개념이 붙은 스크랩이 없어요',
                    style: AppTypography.caption,
                  ),
                ),
              for (final s in detail.scraps)
                // TODO: 스크랩 상세 화면이 생기면 onTap 연결.
                ConceptScrapEntry(scrap: s, conceptName: concept.name),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: '연결된 개념', count: linkCount),
              const SizedBox(height: AppSpacing.sm),
              for (final l in detail.links)
                LinkedConceptRow(
                  linked: l,
                  onOpen: () => context.push(AppRoutes.concept(l.concept.id)),
                  // 관리 탭의 "확인 기다리는 제안"에서 승인·거절한다.
                  onReviewSuggestion: () =>
                      context.go(AppRoutes.manageRelations),
                ),
              if (first != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${first.savedOn.month}월 ${first.savedOn.day}일, '
                  '${first.sourceName}에서 처음 등장',
                  style: AppTypography.caption,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('개념을 찾을 수 없어요', style: AppTypography.body),
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
