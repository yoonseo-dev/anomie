import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/data/concept_graph_repository.dart';
import '../../shared/models/concept_graph.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/concept_graph/concept_graph_view.dart';
import '../../shared/widgets/concept_graph/radial_layout.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/corner_marks.dart';
import 'map_controller.dart';
import 'widgets/focus_summary_card.dart';
import 'widgets/graph_legend.dart';
import 'widgets/hidden_concepts_sheet.dart';
import 'widgets/map_breadcrumb.dart';

/// 마인드맵 (Figma 14:109).
///
/// 그래프는 화면 전체에 깔리고, 상단바·이동 경로·범례·개념 카드가 그 위에 얹힌다.
/// 개념 카드는 하단 메뉴와 그 뒤 그라데이션보다 위에 뜬다.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _transform = TransformationController();

  /// 그래프 위에 얹힌 UI의 대략적인 높이. 개념을 이 사이 빈 공간에 배치한다.
  /// 상단바(44) + 간격(8) + 이동 경로 줄(20).
  static const double _topChromeHeight = 72;

  /// 범례(14) + 간격(16) + 개념 카드(56) + 여유(12).
  static const double _bottomChromeHeight = 98;

  /// 마지막으로 화면 맞춤을 적용한 (가운데 개념, 화면 크기).
  (String, Size)? _fittedFor;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Widget _buildGraph(ConceptGraph graph, String focusId, EdgeInsets insets) {
    final controller = ref.read(mapTrailProvider.notifier);
    final layout = ConceptGraphStyle.full.layoutFor(graph, focusId);
    final canvas = ConceptGraphCanvas(
      layout: layout,
      style: ConceptGraphStyle.full,
      onNodeTap: controller.focus,
      onOverflowTap: (parentId) => _showHidden(graph, layout, parentId),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 처음 열 때와 가운데 개념이 바뀔 때, 1단계 고리가 빈 공간에 들어오게 맞춘다.
        final key = (focusId, constraints.biggest);
        if (key != _fittedFor) {
          final matrix = fitGraphTransform(
            layout: layout,
            origin: canvas.origin,
            visible: insets.deflateRect(Offset.zero & constraints.biggest),
          );
          if (_fittedFor == null) {
            // 아직 InteractiveViewer가 없으니 바로 넣어도 된다.
            _transform.value = matrix;
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _transform.value = matrix;
            });
          }
          _fittedFor = key;
        }

        return InteractiveViewer(
          transformationController: _transform,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.3,
          maxScale: 2.5,
          // 가운데 개념이 바뀌면 새 배치를 살짝 나타나게 한다.
          child: TweenAnimationBuilder<double>(
            key: ValueKey(focusId),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 220),
            builder: (context, t, child) => Opacity(opacity: t, child: child),
            child: canvas,
          ),
        );
      },
    );
  }

  Future<void> _showHidden(
    ConceptGraph graph,
    GraphLayout layout,
    String parentId,
  ) async {
    final picked = await HiddenConceptsSheet.show(
      context,
      parentName: graph.node(parentId)?.name ?? '',
      concepts: layout.hidden[parentId] ?? const [],
    );
    if (picked != null && mounted) {
      ref.read(mapTrailProvider.notifier).focus(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final graphAsync = ref.watch(conceptGraphProvider);
    final trail = ref.watch(mapTrailProvider);
    final controller = ref.read(mapTrailProvider.notifier);

    final graph = graphAsync.value;
    // 관리 화면에서 지금 개념을 삭제·병합했다면 스크랩이 가장 많은 개념으로 돌아간다.
    final focus = trail.isEmpty
        ? null
        : graph?.node(trail.last) ?? graph?.mostScrapped;
    final trailNodes = graph == null
        ? const <ConceptNode>[]
        : trail.map(graph.node).nonNulls.toList();

    final media = MediaQuery.of(context);
    final graphInsets = EdgeInsets.only(
      top: media.padding.top + _topChromeHeight,
      bottom: AppShell.floatingContentInset(context) + _bottomChromeHeight,
    );

    return PopScope(
      canPop: trail.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.back();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: graphAsync.when(
                data: (g) => focus == null
                    ? const SizedBox.shrink()
                    : _buildGraph(g, focus.id, graphInsets),
                loading: () => const LoadingIndicator(),
                error: (_, _) => Center(
                  child: LoadError(
                    onRetry: () => ref.invalidate(conceptGraphProvider),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _MapTopBar(onBack: trail.length > 1 ? controller.back : null),
                  const SizedBox(height: AppSpacing.xs),
                  CornerMarks(
                    child: MapBreadcrumb(
                      trail: trailNodes,
                      onTap: controller.focus,
                    ),
                  ),
                  const Spacer(),
                  if (graph != null && focus != null) ...[
                    const GraphLegend(),
                    const SizedBox(height: AppSpacing.md),
                    ContentWidth(
                      child: FocusSummaryCard(
                        graph: graph,
                        concept: focus,
                        onDetail: () =>
                            context.push(AppRoutes.concept(focus.id)),
                      ),
                    ),
                  ],
                  SizedBox(height: AppShell.floatingContentInset(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapTopBar extends StatelessWidget {
  const _MapTopBar({this.onBack});

  /// null이면 뒤로 버튼을 숨긴다 (지나온 개념이 없을 때).
  final VoidCallback? onBack;

  static const _buttonSize = BoxConstraints.tightFor(width: 44, height: 44);

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: onBack == null
                  ? null
                  : IconButton(
                      onPressed: onBack,
                      tooltip: '이전 개념',
                      padding: EdgeInsets.zero,
                      constraints: _buttonSize,
                      style: const ButtonStyle(alignment: Alignment.centerLeft),
                      icon: const Icon(Icons.chevron_left, size: 28),
                    ),
            ),
            Expanded(
              child: Text(
                'MAP',
                style: AppTypography.brandSmall,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              // TODO: 개념 검색 화면 디자인이 나오면 연결.
              onPressed: null,
              tooltip: '개념 검색',
              padding: EdgeInsets.zero,
              constraints: _buttonSize,
              style: const ButtonStyle(alignment: Alignment.centerRight),
              icon: SvgPicture.asset(
                'assets/icons/search.svg',
                width: 22,
                height: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
