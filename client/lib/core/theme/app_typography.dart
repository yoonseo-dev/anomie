import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// 글꼴 지정은 이 파일에서만 한다.
///
/// - Lexend Zetta: 한글을 지원하지 않으므로 영문 브랜드 글자(ANOMIE, MAP)에만 쓴다.
/// - Gothic A1: 그 밖의 모든 글자 (한글 제목은 Bold).
///
/// 나중에 글꼴 파일을 에셋으로 옮길 때는 [_brandFont]와 [_bodyFont] 두 함수만
/// `style.copyWith(fontFamily: '...')`로 바꾸면 된다.
abstract final class AppTypography {
  static TextStyle _brandFont(TextStyle style) =>
      GoogleFonts.lexendZetta(textStyle: style);

  static TextStyle _bodyFont(TextStyle style) =>
      GoogleFonts.gothicA1(textStyle: style);

  static TextStyle _body(double size, FontWeight weight, {double? height}) =>
      _bodyFont(
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: AppColors.black,
        ),
      );

  // ── 브랜드 (영문 전용) ────────────────────────────────────────────

  /// 홈 상단 "ANOMIE" 워드마크.
  static TextStyle get brandLarge => _brandFont(
    const TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w300,
      letterSpacing: -0.72,
      color: AppColors.black,
    ),
  );

  /// 상단바의 "MAP" 같은 작은 영문 제목.
  static TextStyle get brandSmall => _brandFont(
    const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w300,
      letterSpacing: -0.3,
      color: AppColors.black,
    ),
  );

  // ── 본문 (Gothic A1) ─────────────────────────────────────────────

  /// 상세 화면 맨 위 개념 이름 ("아노미").
  static TextStyle get displayTitle => _body(36, FontWeight.w700);

  /// 화면 큰 제목 ("어떤 기사를 스크랩할까요").
  static TextStyle get headline => _body(24, FontWeight.w700, height: 1.35);

  /// 카드 제목 ("기사", "책").
  static TextStyle get title => _body(20, FontWeight.w700);

  /// 섹션 제목 큰 것 ("찾은 개념").
  static TextStyle get sectionLarge => _body(18, FontWeight.w700);

  /// 카드 안 제목 ("내 개념").
  static TextStyle get sectionMedium => _body(16, FontWeight.w700);

  /// 섹션 제목 ("최근 스크랩").
  static TextStyle get section => _body(15, FontWeight.w700);

  /// 상단바 가운데 제목.
  static TextStyle get appBarTitle => _body(15, FontWeight.w600);

  /// 목록 제목, 강조 본문.
  static TextStyle get bodyStrong => _body(14, FontWeight.w500);

  /// 굵게 강조한 본문 (관리 화면의 제안 카드 "아노미 ----- 소외").
  static TextStyle get bodyEmphasis => _body(14, FontWeight.w600);

  /// 입력값, 일반 본문.
  static TextStyle get body => _body(14, FontWeight.w400, height: 1.7);

  /// 여러 줄 설명문.
  static TextStyle get bodySmall => _body(12, FontWeight.w400, height: 1.6);

  /// 큰 버튼 글자.
  static TextStyle get button => _body(14, FontWeight.w600);

  /// 작은 버튼 글자.
  static TextStyle get buttonSmall => _body(12, FontWeight.w600);

  /// 탭·세그먼트 선택된 칸.
  static TextStyle get tabSelected => _body(13, FontWeight.w600);

  /// 탭·세그먼트 선택 안 된 칸.
  static TextStyle get tab => _body(13, FontWeight.w500);

  /// 태그 칩, 밑줄 링크.
  static TextStyle get chip => _body(12, FontWeight.w500);

  /// 밑줄 글자 버튼 ("이름 수정하기", "빼기").
  static TextStyle get link =>
      _body(12, FontWeight.w500).copyWith(decoration: TextDecoration.underline);

  /// 작은 밑줄 글자 버튼 ("제안 확인하기").
  static TextStyle get linkSmall =>
      _body(11, FontWeight.w500).copyWith(decoration: TextDecoration.underline);

  /// 섹션 제목 옆 개수 ("3", "2 + 제안 1").
  static TextStyle get sectionCount => _body(13, FontWeight.w400);

  /// 원문 카드의 기사 제목처럼 두세 줄로 넘어가는 강조 본문.
  static TextStyle get articleTitle => _body(14, FontWeight.w500, height: 1.5);

  /// 보조 설명, 입력창 라벨, 출처.
  static TextStyle get caption => _body(11, FontWeight.w400);

  /// 범례처럼 조금 더 또렷한 보조 글자 ("새 제안 1").
  static TextStyle get captionMedium => _body(11, FontWeight.w500);

  /// 보조 글자 중 강조 (이동 경로의 현재 개념).
  static TextStyle get captionStrong => _body(11, FontWeight.w600);

  /// 그래프 노드 이름처럼 아주 작은 글자.
  static TextStyle get micro => _body(10, FontWeight.w500, height: 1.2);

  /// 워드마크 아래 부제 ("개념 노트").
  static TextStyle get tagline =>
      _body(12, FontWeight.w500).copyWith(letterSpacing: 0.48);

  // ── 개념 그래프 (마인드맵 크기) ────────────────────────────────────

  /// 가운데 개념 원 안의 이름.
  static TextStyle get graphFocus => _body(17, FontWeight.w600, height: 1.2);

  /// 연결된 개념 원 안의 이름.
  static TextStyle get graphNode => _body(12, FontWeight.w600, height: 1.2);

  /// 작은 점 옆 이름표.
  static TextStyle get graphPoint => _body(11, FontWeight.w500);

  // ── 개념 그래프 (홈 미리보기 크기) ─────────────────────────────────

  /// 가운데 개념 원 안의 이름.
  static TextStyle get graphFocusSmall =>
      _body(13, FontWeight.w600, height: 1.2);

  /// 연결된 개념 원 안의 이름.
  static TextStyle get graphNodeSmall =>
      _body(10, FontWeight.w600, height: 1.2);

  /// 작은 점 옆 이름표.
  static TextStyle get graphPointSmall => _body(10, FontWeight.w500);

  /// Material 위젯이 기본으로 읽는 TextTheme.
  static TextTheme get textTheme => TextTheme(
    displayLarge: brandLarge,
    headlineMedium: headline,
    headlineSmall: title,
    titleLarge: sectionLarge,
    titleMedium: sectionMedium,
    titleSmall: section,
    bodyLarge: bodyStrong,
    bodyMedium: body,
    bodySmall: bodySmall,
    labelLarge: button,
    labelMedium: tab,
    labelSmall: caption,
  );
}
