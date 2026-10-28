import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/data/concept_graph_repository.dart';
import '../../shared/models/concept_graph.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/corner_marks.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/segmented_toggle.dart';
import '../../shared/widgets/tag_chip.dart';
import '../../shared/widgets/text_edit_sheet.dart';
import 'concept_actions.dart';
import 'widgets/concept_list_row.dart';
import 'widgets/merge_target_sheet.dart';
import 'widgets/relation_menu_sheet.dart';
import 'widgets/relation_row.dart';
import 'widgets/suggestion_card.dart';

enum ManageTab {
  tags,
  relations;

  /// 라우트 쿼리 값(`?tab=relations`)에서 읽는다. 모르는 값이면 태그 탭.
  static ManageTab fromQuery(String? value) =>
      values.firstWhere((t) => t.name == value, orElse: () => tags);
}

enum ConceptSort {
  scraps('스크랩 많은 순'),
  name('이름순'),
  recent('최근 추가순');

  const ConceptSort(this.label);

  final String label;
}

/// 관리 (Figma 18:170 태그 / 18:99 관계). 하단 메뉴가 있는 탭 화면이다.
class ManageScreen extends ConsumerStatefulWidget {
  const ManageScreen({super.key, this.initialTab = ManageTab.tags});

  final ManageTab initialTab;

  @override
  ConsumerState<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends ConsumerState<ManageScreen> {
  late ManageTab _tab = widget.initialTab;
  ConceptSort _sort = ConceptSort.scraps;

  @override
  void didUpdateWidget(ManageScreen old) {
    super.didUpdateWidget(old);
    // 다른 화면에서 ?tab=relations로 들어오면 그 탭으로 바꾼다.
    if (old.initialTab != widget.initialTab) _tab = widget.initialTab;
  }

  ConceptActions get _actions => ref.read(conceptActionsProvider);

  void _openConcept(String id) => context.push(AppRoutes.concept(id));

  void _snack(String message, {VoidCallback? undo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: undo == null
              ? null
              : SnackBarAction(label: '되돌리기', onPressed: undo),
        ),
      );
  }

  Future<void> _remove(ConceptLink link, String message) async {
    final removed = await _actions.remove(link);
    if (removed == null || !mounted) return;
    _snack(message, undo: () => _actions.restore(removed));
  }

  Future<void> _editReason(ConceptLink link) async {
    final text = await TextEditSheet.show(
      context,
      title: '연결 이유 수정하기',
      initialText: link.reason ?? '',
      emptyMessage: '연결 이유를 넣어 주세요',
      multiline: true,
    );
    if (text != null) await _actions.updateReason(link, text);
  }

  Future<void> _openRelationMenu(ConceptGraph graph, ConceptLink link) async {
    final a = graph.node(link.sourceId)?.name ?? '';
    final b = graph.node(link.targetId)?.name ?? '';
    final action = await RelationMenuSheet.show(context, title: '$a ── $b');
    switch (action) {
      case RelationMenuAction.edit:
        await _editReason(link);
      case RelationMenuAction.unlink:
        await _remove(link, '연결을 끊었어요');
      case null:
        break;
    }
  }

  Future<void> _merge(ConceptGraph graph, ConceptNode from) async {
    final into = await MergeTargetSheet.show(
      context,
      from: from,
      candidates: graph.nodes.where((n) => n.id != from.id).toList(),
    );
    if (into == null || !mounted) return;
    final ok = await showConfirmDialog(
      context,
      title: '${from.name}을(를) ${into.name}에 합칠까요?',
      message:
          '${from.name} 태그가 붙은 스크랩과 연결이 모두 ${into.name}(으)로 옮겨지고, '
          '${from.name}은(는) 사라져요. 되돌릴 수 없어요.',
      confirmLabel: '병합',
    );
    if (!ok) return;
    await _actions.merge(from, into);
    if (mounted) _snack('${into.name}에 합쳤어요');
  }

  Future<void> _delete(ConceptGraph graph, ConceptNode concept) async {
    final links = graph.linksOf(concept.id).length;
    final ok = await showConfirmDialog(
      context,
      title: '${concept.name} 태그를 삭제할까요?',
      message:
          '스크랩에서 이 태그가 빠지고 연결 $links개도 함께 사라져요. '
          '되돌릴 수 없어요.',
      confirmLabel: '삭제',
    );
    if (!ok) return;
    await _actions.delete(concept);
    if (mounted) _snack('${concept.name} 태그를 삭제했어요');
  }

  @override
  Widget build(BuildContext context) {
    final graphAsync = ref.watch(conceptGraphProvider);
    final graph = graphAsync.value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: graph == null
            ? graphAsync.hasError
                  ? Center(
                      child: LoadError(
                        onRetry: () => ref.invalidate(conceptGraphProvider),
                      ),
                    )
                  : const LoadingIndicator()
            : ListView(
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.paddingOf(context).bottom +
                      AppSpacing.bottomNavClearance,
                ),
                children: [
                  ContentWidth(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text('관리', style: AppTypography.headline),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const CornerMarks(),
                  const SizedBox(height: AppSpacing.md),
                  ContentWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedToggle<ManageTab>(
                          items: [
                            SegmentedToggleItem(
                              value: ManageTab.tags,
                              label: '태그',
                              count: graph.nodes.length,
                            ),
                            SegmentedToggleItem(
                              value: ManageTab.relations,
                              label: '관계',
                              count: graph.links.length,
                            ),
                          ],
                          selected: _tab,
                          onChanged: (t) => setState(() => _tab = t),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ...switch (_tab) {
                          ManageTab.tags => _tagsTab(graph),
                          ManageTab.relations => _relationsTab(graph),
                        },
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _tagsTab(ConceptGraph graph) {
    int confirmedLinks(String id) =>
        graph.linksOf(id).where((l) => !l.isSuggested).length;

    final concepts = [...graph.nodes]
      ..sort(switch (_sort) {
        ConceptSort.scraps => (a, b) {
          final c = b.scrapCount.compareTo(a.scrapCount);
          return c != 0 ? c : a.name.compareTo(b.name);
        },
        ConceptSort.name => (a, b) => a.name.compareTo(b.name),
        ConceptSort.recent => (a, b) {
          final c = (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          );
          return c != 0 ? c : a.name.compareTo(b.name);
        },
      });

    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in ConceptSort.values)
            TagChip(
              label: s.label,
              size: TagChipSize.small,
              variant: s == _sort
                  ? TagChipVariant.selected
                  : TagChipVariant.confirmed,
              onTap: () => setState(() => _sort = s),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      if (concepts.isEmpty) Text('아직 태그가 없어요', style: AppTypography.caption),
      for (final c in concepts)
        ConceptListRow(
          key: ValueKey(c.id),
          name: c.name,
          scrapCount: c.scrapCount,
          linkCount: confirmedLinks(c.id),
          onOpen: () => _openConcept(c.id),
          onMerge: () => _merge(graph, c),
          onDelete: () => _delete(graph, c),
        ),
    ];
  }

  List<Widget> _relationsTab(ConceptGraph graph) {
    final pending = graph.links.where((l) => l.isSuggested).toList();
    final confirmed = graph.links.where((l) => !l.isSuggested).toList();
    String name(String id) => graph.node(id)?.name ?? '';

    return [
      SectionHeader(title: '확인 기다리는 제안', count: '${pending.length}'),
      const SizedBox(height: 10),
      if (pending.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text('새 제안이 없어요', style: AppTypography.caption),
        ),
      for (final link in pending) ...[
        SuggestionCard(
          key: ValueKey('${link.sourceId}-${link.targetId}'),
          left: name(link.sourceId),
          right: name(link.targetId),
          reason: link.reason,
          onApprove: () async {
            await _actions.approve(link);
            if (mounted) _snack('연결했어요');
          },
          onReject: () => _remove(link, '제안을 거절했어요'),
          onEdit: () => _editReason(link),
          onTapLeft: () => _openConcept(link.sourceId),
          onTapRight: () => _openConcept(link.targetId),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: AppSpacing.xs),
      SectionHeader(title: '연결됨', count: '${confirmed.length}'),
      const SizedBox(height: 10),
      for (final link in confirmed)
        RelationRow(
          key: ValueKey('${link.sourceId}-${link.targetId}'),
          left: name(link.sourceId),
          right: name(link.targetId),
          onMore: () => _openRelationMenu(graph, link),
          onTapLeft: () => _openConcept(link.sourceId),
          onTapRight: () => _openConcept(link.targetId),
        ),
    ];
  }
}
