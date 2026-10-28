import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/scrap_analysis_repository.dart';
import '../../shared/models/scrap.dart';
import '../../shared/models/scrap_analysis.dart';
import 'scrap_validators.dart';

class NewScrapState {
  const NewScrapState({
    required this.source,
    this.url = '',
    this.urlTouched = false,
    this.photo,
    this.bookTitle = '',
    this.author = '',
    this.page = '',
    this.bookTouched = false,
    this.isSubmitting = false,
  });

  final ScrapSource source;

  final String url;

  /// 사용자가 주소 입력을 마쳤는지. 마치기 전에는 오류를 보여 주지 않는다.
  final bool urlTouched;

  final PagePhoto? photo;
  final String bookTitle;
  final String author;
  final String page;
  final bool bookTouched;

  final bool isSubmitting;

  String? get urlError => urlTouched && url.trim().isNotEmpty
      ? ScrapValidators.articleUrl(url)
      : null;

  String? get bookTitleError =>
      bookTouched ? ScrapValidators.bookTitle(bookTitle) : null;

  String? get pageError => ScrapValidators.page(page);

  bool get canSubmit {
    if (isSubmitting) return false;
    return switch (source) {
      ScrapSource.article => ScrapValidators.articleUrl(url) == null,
      ScrapSource.book =>
        photo != null &&
            ScrapValidators.bookTitle(bookTitle) == null &&
            ScrapValidators.page(page) == null,
    };
  }

  NewScrapState copyWith({
    ScrapSource? source,
    String? url,
    bool? urlTouched,
    PagePhoto? photo,
    String? bookTitle,
    String? author,
    String? page,
    bool? bookTouched,
    bool? isSubmitting,
  }) {
    return NewScrapState(
      source: source ?? this.source,
      url: url ?? this.url,
      urlTouched: urlTouched ?? this.urlTouched,
      photo: photo ?? this.photo,
      bookTitle: bookTitle ?? this.bookTitle,
      author: author ?? this.author,
      page: page ?? this.page,
      bookTouched: bookTouched ?? this.bookTouched,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// 새 스크랩 화면 상태. 화면을 닫으면 입력값도 함께 사라진다.
class NewScrapController extends Notifier<NewScrapState> {
  NewScrapController(this.initialSource);

  final ScrapSource initialSource;

  @override
  NewScrapState build() => NewScrapState(source: initialSource);

  void selectSource(ScrapSource source) =>
      state = state.copyWith(source: source);

  void setUrl(String url, {bool touched = false}) =>
      state = state.copyWith(url: url, urlTouched: touched || state.urlTouched);

  void markUrlTouched() => state = state.copyWith(urlTouched: true);

  /// 가짜 촬영. 실제 카메라를 붙이면 촬영한 파일 경로를 넘긴다.
  void capturePhoto([PagePhoto photo = const PagePhoto()]) =>
      state = state.copyWith(photo: photo);

  void setBookTitle(String value) => state = state.copyWith(bookTitle: value);

  void markBookTouched() => state = state.copyWith(bookTouched: true);

  void setAuthor(String value) => state = state.copyWith(author: value);

  void setPage(String value) => state = state.copyWith(page: value);

  /// 분석을 요청하고 결과를 [latestAnalysisProvider]에 담는다.
  /// 입력이 아직 맞지 않으면 아무것도 하지 않고 false를 돌려준다.
  Future<bool> submit() async {
    if (!state.canSubmit) return false;
    state = state.copyWith(isSubmitting: true);
    final repo = ref.read(scrapAnalysisRepositoryProvider);

    try {
      final analysis = switch (state.source) {
        ScrapSource.article => await repo.analyzeArticle(state.url.trim()),
        ScrapSource.book => await repo.analyzeBookPage(
          photo: state.photo!,
          title: state.bookTitle.trim(),
          author: state.author.trim().isEmpty ? null : state.author.trim(),
          page: int.tryParse(state.page.trim()),
        ),
      };
      ref.read(latestAnalysisProvider.notifier).set(analysis);
      return true;
    } finally {
      if (ref.mounted) state = state.copyWith(isSubmitting: false);
    }
  }
}

final newScrapControllerProvider = NotifierProvider.autoDispose
    .family<NewScrapController, NewScrapState, ScrapSource>(
      NewScrapController.new,
    );
