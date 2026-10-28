import 'package:flutter/painting.dart';

/// Anomie는 검정/흰색 두 가지 색만 쓴다 (Figma 변수 `mono/black`, `mono/white`).
/// 회색이 필요한 곳은 새 색을 만들지 않고 검정·흰색의 투명도로 표현한다.
abstract final class AppColors {
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  /// 비활성 버튼 배경 (Figma: 검정 버튼 opacity 25%).
  static const Color disabled = Color(0x40000000);

  /// 입력창 placeholder (Figma: opacity 35%).
  static const Color hint = Color(0x59000000);

  /// 얇은 구분선, 보조 테두리.
  static const Color divider = Color(0x1F000000);

  /// 흰색 그라데이션의 시작점 (완전 투명한 흰색).
  static const Color whiteClear = Color(0x00FFFFFF);

  /// 흰 바탕 위 눌림/호버/포커스 효과.
  static const Color pressedOnWhite = Color(0x14000000);

  /// 검정 바탕 위 눌림/호버/포커스 효과.
  static const Color pressedOnBlack = Color(0x29FFFFFF);
}
