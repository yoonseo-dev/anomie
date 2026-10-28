import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/outlined_card.dart';
import '../../shared/widgets/pill_bottom_nav.dart';
import '../../shared/widgets/pill_button.dart';
import '../../shared/widgets/segmented_toggle.dart';
import '../../shared/widgets/tag_chip.dart';

/// 공통 위젯의 모든 변형을 한 화면에서 확인하는 개발용 화면.
/// 라우터에서 디버그 모드일 때만 등록된다.
class WidgetGalleryScreen extends StatefulWidget {
  const WidgetGalleryScreen({super.key});

  @override
  State<WidgetGalleryScreen> createState() => _WidgetGalleryScreenState();
}

enum _Source { article, book }

class _WidgetGalleryScreenState extends State<WidgetGalleryScreen> {
  _Source _source = _Source.article;
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('위젯 갤러리')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('글자'),
                Text('ANOMIE', style: AppTypography.brandLarge),
                Text('MAP', style: AppTypography.brandSmall),
                Text('어떤 기사를\n스크랩할까요', style: AppTypography.headline),
                Text('찾은 개념', style: AppTypography.sectionLarge),
                Text('최근 스크랩', style: AppTypography.section),
                Text('청년 고용률 4년 만에 하락 전환', style: AppTypography.bodyStrong),
                Text(
                  '또래나 부모 세대와 비교해 기대한 몫을 얻지 못한다는 인식.',
                  style: AppTypography.bodySmall,
                ),
                Text('한겨레 · 10월 8일', style: AppTypography.caption),

                _section('PillButton'),
                PillButton(label: '분석하기', onPressed: () {}, expand: true),
                const SizedBox(height: AppSpacing.xs),
                const PillButton(
                  label: '분석하기 (비활성)',
                  onPressed: null,
                  expand: true,
                ),
                const SizedBox(height: AppSpacing.xs),
                PillButton(
                  label: '저장 중',
                  onPressed: () {},
                  isLoading: true,
                  expand: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    PillButton(
                      label: '승인',
                      onPressed: () {},
                      size: PillButtonSize.small,
                    ),
                    PillButton(
                      label: '거절',
                      onPressed: () {},
                      size: PillButtonSize.small,
                      variant: PillButtonVariant.outlined,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedCard(
                  variant: OutlinedCardVariant.inverted,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'hani.co.kr/arti/society/1162',
                          style: AppTypography.bodyStrong.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                      ),
                      PillButton(
                        label: '붙여넣기',
                        onPressed: () {},
                        size: PillButtonSize.small,
                        variant: PillButtonVariant.inverted,
                      ),
                    ],
                  ),
                ),

                _section('TagChip'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TagChip(label: '상대적 박탈감', onTap: () {}),
                    TagChip(
                      label: '이행기 지연',
                      variant: TagChipVariant.suggested,
                      onTap: () {},
                    ),
                    TagChip(
                      label: '아노미',
                      variant: TagChipVariant.selected,
                      onTap: () {},
                    ),
                    TagChip(label: '위험사회', onDelete: () {}),
                  ],
                ),

                _section('AppTextField'),
                const AppTextField(label: '기사 주소', hintText: 'https://'),
                const SizedBox(height: AppSpacing.md),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: '저자 (선택)',
                        initialValue: '에밀 뒤르켐',
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        label: '페이지',
                        initialValue: '214',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const AppTextField(
                  label: '오류 상태',
                  initialValue: 'not-a-url',
                  errorText: '기사 주소를 확인해 주세요',
                ),

                _section('SegmentedToggle'),
                SegmentedToggle<_Source>(
                  items: const [
                    SegmentedToggleItem(value: _Source.article, label: '기사'),
                    SegmentedToggleItem(value: _Source.book, label: '책'),
                  ],
                  selected: _source,
                  onChanged: (v) => setState(() => _source = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedToggle<int>(
                  items: const [
                    SegmentedToggleItem(value: 0, label: '태그', count: 15),
                    SegmentedToggleItem(value: 1, label: '관계', count: 14),
                  ],
                  selected: _tab,
                  onChanged: (v) => setState(() => _tab = v),
                ),

                _section('OutlinedCard'),
                for (final variant in OutlinedCardVariant.values) ...[
                  OutlinedCard(
                    variant: variant,
                    onTap: () {},
                    child: Text(
                      variant.name,
                      style: AppTypography.bodyStrong.copyWith(
                        color: variant == OutlinedCardVariant.inverted
                            ? AppColors.white
                            : AppColors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                _section('PillBottomNav'),
                Center(
                  child: PillBottomNav(
                    labels: const ['홈', '마인드맵', '관리'],
                    currentIndex: _tab.clamp(0, 2),
                    onTap: (i) => setState(() => _tab = i),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.sm),
    child: Text(title, style: AppTypography.sectionLarge),
  );
}
