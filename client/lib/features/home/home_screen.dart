import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/data/concept_graph_repository.dart';
import '../../shared/data/scrap_repository.dart';
import '../../shared/models/scrap.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/outlined_card.dart';
import 'widgets/concept_map_preview_card.dart';
import 'widgets/home_header.dart';
import 'widgets/quick_add_card.dart';
import 'widgets/recent_scrap_tile.dart';

/// 홈 (Figma 14:16).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openNewScrap(BuildContext context, ScrapSource source) {
    context.push('${AppRoutes.scrapNew}?type=${source.name}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(conceptGraphProvider);
    final scraps = ref.watch(recentScrapsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            ref.refresh(conceptGraphProvider.future),
            ref.refresh(recentScrapsProvider.future),
          ]),
          child: ListView(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.bottomNavClearance,
            ),
            children: [
              // TODO: 메뉴 화면 디자인이 나오면 연결.
              const HomeHeader(),
              const SizedBox(height: AppSpacing.sm),
              ContentWidth(
                child: graph.when(
                  data: (g) => ConceptMapPreviewCard(
                    graph: g,
                    onTap: () => context.go(AppRoutes.map),
                  ),
                  loading: () => const _CardSlot(child: LoadingIndicator()),
                  error: (_, _) => _CardSlot(
                    child: LoadError(
                      onRetry: () => ref.invalidate(conceptGraphProvider),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ContentWidth(
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, source) in ScrapSource.values.indexed) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: QuickAddCard(
                            source: source,
                            onTap: () => _openNewScrap(context, source),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ContentWidth(
                child: Row(
                  children: [
                    Expanded(
                      child: Text('최근 스크랩', style: AppTypography.section),
                    ),
                    // TODO: 스크랩 전체 목록 화면이 생기면 연결.
                    const TextButton(onPressed: null, child: Text('전체')),
                  ],
                ),
              ),
              ContentWidth(
                child: scraps.when(
                  data: (items) => items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          child: Text(
                            '아직 스크랩이 없어요',
                            style: AppTypography.caption,
                          ),
                        )
                      : Column(
                          children: [
                            for (final s in items)
                              // TODO: 스크랩 상세 화면이 생기면 onTap 연결.
                              RecentScrapTile(scrap: s),
                          ],
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: LoadingIndicator(),
                  ),
                  error: (_, _) => LoadError(
                    onRetry: () => ref.invalidate(recentScrapsProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 그래프 카드가 들어갈 자리를 같은 비율로 잡아 둔다 (불러오는 중·오류).
class _CardSlot extends StatelessWidget {
  const _CardSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: ConceptMapPreviewCard.aspectRatio,
        child: Center(child: child),
      ),
    );
  }
}
