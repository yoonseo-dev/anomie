import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_dimens.dart';
import '../../shared/models/scrap.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/corner_marks.dart';
import '../../shared/widgets/pill_button.dart';
import '../../shared/widgets/segmented_toggle.dart';
import 'new_scrap_controller.dart';
import 'widgets/article_form.dart';
import 'widgets/book_form.dart';

/// 새 스크랩 (Figma 16:225 기사 / 16:278 책). 하단 메뉴 없이 위로 덮는 화면이다.
class NewScrapScreen extends ConsumerStatefulWidget {
  const NewScrapScreen({super.key, this.initialSource = ScrapSource.article});

  final ScrapSource initialSource;

  @override
  ConsumerState<NewScrapScreen> createState() => _NewScrapScreenState();
}

class _NewScrapScreenState extends ConsumerState<NewScrapScreen> {
  final _url = TextEditingController();
  final _urlFocus = FocusNode();
  final _title = TextEditingController();
  final _titleFocus = FocusNode();
  final _author = TextEditingController();
  final _page = TextEditingController();

  late final _provider = newScrapControllerProvider(widget.initialSource);

  NewScrapController get _controller => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
    // 입력창을 벗어나면 그때부터 오류를 보여 준다.
    _urlFocus.addListener(() {
      if (!_urlFocus.hasFocus) _controller.markUrlTouched();
    });
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) _controller.markBookTouched();
    });
  }

  @override
  void dispose() {
    for (final c in [_url, _title, _author, _page]) {
      c.dispose();
    }
    _urlFocus.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _paste(String url) {
    _url.text = url;
    _controller.setUrl(url, touched: true);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    try {
      final ok = await _controller.submit();
      // 새 스크랩 화면은 아래에 남겨 두어, 태그 확인에서 ‹로 돌아와 입력을 고칠 수 있게 한다.
      if (ok && mounted) context.push(AppRoutes.tagReview);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('분석하지 못했어요. 잠시 뒤 다시 시도해 주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final isArticle = state.source == ScrapSource.article;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 54,
        leading: Padding(
          // 아이콘이 왼쪽 여백선(20)에 오도록 맞춘다.
          padding: const EdgeInsets.only(left: 6),
          child: IconButton(
            tooltip: '닫기',
            onPressed: () => context.pop(),
            icon: SvgPicture.asset(
              'assets/icons/close.svg',
              width: 20,
              height: 20,
            ),
          ),
        ),
        title: const Text('새 스크랩'),
      ),
      body: Column(
        children: [
          const CornerMarks(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xl,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedToggle<ScrapSource>(
                      items: const [
                        SegmentedToggleItem(
                          value: ScrapSource.article,
                          label: '기사',
                        ),
                        SegmentedToggleItem(
                          value: ScrapSource.book,
                          label: '책',
                        ),
                      ],
                      selected: state.source,
                      onChanged: _controller.selectSource,
                    ),
                    if (isArticle)
                      ArticleForm(
                        controller: _url,
                        focusNode: _urlFocus,
                        errorText: state.urlError,
                        onChanged: _controller.setUrl,
                        onSubmitted: (_) => _controller.markUrlTouched(),
                        onPaste: _paste,
                      )
                    else
                      BookForm(
                        photo: state.photo,
                        onCapture: _controller.capturePhoto,
                        titleController: _title,
                        titleFocusNode: _titleFocus,
                        authorController: _author,
                        pageController: _page,
                        titleError: state.bookTitleError,
                        pageError: state.pageError,
                        onTitleChanged: _controller.setBookTitle,
                        onAuthorChanged: _controller.setAuthor,
                        onPageChanged: _controller.setPage,
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
                  label: '분석하기',
                  expand: true,
                  isLoading: state.isSubmitting,
                  onPressed: state.canSubmit ? _submit : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
