import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/concept_detail_provider.dart';
import '../../shared/data/concept_graph_repository.dart';
import '../../shared/data/scrap_analysis_repository.dart';
import '../../shared/data/scrap_repository.dart';
import '../../shared/models/scrap_analysis.dart';

/// 저장하기 전 태그 하나의 상태.
class TagDraft {
  const TagDraft({
    required this.suggestion,
    required this.name,
    required this.isNew,
    this.replacedWith,
    this.removed = false,
    this.excerpt,
    this.excerptEdited = false,
  });

  factory TagDraft.from(SuggestedTag tag) => TagDraft(
    suggestion: tag,
    name: tag.name,
    isNew: tag.isNew,
    excerpt: tag.excerpt,
  );

  /// AI가 처음 제안한 내용 (이유, 비슷한 내 태그).
  final SuggestedTag suggestion;

  /// 지금 이름 (이름 수정하기를 하면 바뀐다).
  final String name;

  /// 내 개념 목록에 없는 새 태그인지.
  final bool isNew;

  /// "비슷한 내 태그로 바꾸기"로 고른 내 태그.
  final String? replacedWith;

  final bool removed;

  /// 책의 근거 문장 (근거 문장 수정하기를 하면 바뀐다). 기사면 null.
  final String? excerpt;

  /// 사용자가 근거 문장을 고쳤는지. 실물 책과 대조해 고친 것이므로 "확인 필요"를 거둔다.
  final bool excerptEdited;

  /// OCR 텍스트에서 그대로 찾지 못한 근거 문장이라 실물 책과 대조가 필요한지.
  bool get excerptNeedsCheck =>
      excerpt != null && !suggestion.excerptVerified && !excerptEdited;

  /// 저장될 이름.
  String get finalName => replacedWith ?? name;

  /// 화면에 새 태그(점선)로 보일지.
  bool get showsAsNew => isNew && replacedWith == null;

  TagDraft copyWith({
    String? name,
    bool? isNew,
    String? Function()? replacedWith,
    bool? removed,
    String? excerpt,
  }) {
    return TagDraft(
      suggestion: suggestion,
      name: name ?? this.name,
      isNew: isNew ?? this.isNew,
      replacedWith: replacedWith != null ? replacedWith() : this.replacedWith,
      removed: removed ?? this.removed,
      excerpt: excerpt ?? this.excerpt,
      excerptEdited: excerpt != null || excerptEdited,
    );
  }
}

class TagReviewState {
  const TagReviewState({
    required this.analysis,
    required this.drafts,
    this.isSaving = false,
  });

  /// null이면 확인할 분석 결과가 없다 (주소로 바로 들어온 경우 등).
  final ScrapAnalysis? analysis;

  /// 뺀 태그도 자리를 지킨다. 그래서 index가 바뀌지 않고 되돌리기가 쉽다.
  final List<TagDraft> drafts;

  final bool isSaving;

  Iterable<TagDraft> get kept => drafts.where((d) => !d.removed);

  int get keptCount => kept.length;

  bool get canSave => analysis != null && keptCount > 0 && !isSaving;

  TagReviewState copyWith({List<TagDraft>? drafts, bool? isSaving}) =>
      TagReviewState(
        analysis: analysis,
        drafts: drafts ?? this.drafts,
        isSaving: isSaving ?? this.isSaving,
      );
}

/// 태그 확인 화면 상태. 화면을 나가면 고친 내용도 사라진다.
class TagReviewController extends Notifier<TagReviewState> {
  static const renameEmptyMessage = '태그 이름을 넣어 주세요';
  static const excerptEmptyMessage = '근거 문장을 넣어 주세요';

  @override
  TagReviewState build() {
    // 화면에 들어온 순간의 결과로 시작한다. 나중에 결과가 바뀌어도 고친 내용을 지우지 않는다.
    final analysis = ref.read(latestAnalysisProvider);
    return TagReviewState(
      analysis: analysis,
      drafts: [for (final t in analysis?.tags ?? const []) TagDraft.from(t)],
    );
  }

  void _update(int index, TagDraft Function(TagDraft d) change) {
    final drafts = [...state.drafts];
    drafts[index] = change(drafts[index]);
    state = state.copyWith(drafts: drafts);
  }

  /// 비슷한 내 태그로 바꾼다. 이미 그 태그로 바꿨다면 원래 새 태그로 되돌린다.
  void toggleReplacement(int index, String existing) => _update(
    index,
    (d) => d.copyWith(
      replacedWith: () => d.replacedWith == existing ? null : existing,
    ),
  );

  /// 이름을 고친다. 바꾸기를 골라 둔 상태였다면 그 선택은 풀린다.
  void rename(int index, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final known =
        ref
            .read(conceptGraphProvider)
            .value
            ?.nodes
            .any((n) => n.name == trimmed) ??
        false;
    _update(
      index,
      (d) => d.copyWith(name: trimmed, isNew: !known, replacedWith: () => null),
    );
  }

  /// 근거 문장을 고친다. 빈 문장은 무시한다 (책 저장에는 근거 문장이 필요하다).
  void editExcerpt(int index, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _update(index, (d) => d.copyWith(excerpt: trimmed));
  }

  void remove(int index) => _update(index, (d) => d.copyWith(removed: true));

  void restore(int index) => _update(index, (d) => d.copyWith(removed: false));

  /// 저장할 태그. 같은 이름은 처음 것만 남긴다.
  /// AI가 쓴 설명·분야는 제안 그대로의 새 태그일 때만 보낸다. 내 개념으로 바꿨으면 서버가 같은
  /// 이름의 내 개념에 붙이고(이름은 사용자 안에서 유일), 이름을 고쳤으면 원래 설명은 다른 개념의 것이다.
  List<ApprovedTag> get approvedTags {
    final seen = <String>{};
    return [
      for (final d in state.kept)
        if (seen.add(d.finalName))
          ApprovedTag(
            name: d.finalName,
            reason: d.suggestion.reason,
            explanation: d.suggestion.explanation,
            category: d.showsAsNew ? d.suggestion.category : null,
            description: d.showsAsNew && d.name == d.suggestion.name
                ? d.suggestion.description
                : null,
            excerpt: d.excerpt,
          ),
    ];
  }

  /// 남은 태그로 스크랩을 저장한다. 같은 이름은 한 번만 저장한다.
  /// 실패하면 [ApiException]을 던진다 (화면이 문구를 보여 준다).
  Future<bool> save() async {
    final analysis = state.analysis;
    if (!state.canSave || analysis == null) return false;
    state = state.copyWith(isSaving: true);
    try {
      await ref.read(scrapRepositoryProvider).save(analysis, approvedTags);
      // 새 개념이 생겼을 수 있다. 관계 제안은 서버가 저장 뒤에 따로 만든다.
      ref
        ..invalidate(recentScrapsProvider)
        ..invalidate(conceptGraphProvider)
        ..invalidate(conceptDetailProvider);
      return true;
    } finally {
      if (ref.mounted) state = state.copyWith(isSaving: false);
    }
  }
}

final tagReviewControllerProvider =
    NotifierProvider.autoDispose<TagReviewController, TagReviewState>(
      TagReviewController.new,
    );
