/// 여백·모서리·선 굵기 토큰. Figma 값에서 가져왔고, 화면 배치는 이 값과
/// Flex 레이아웃만으로 구성한다 (절대 좌표 사용 금지).
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// 화면 좌우 여백.
  static const double gutter = 20;

  /// 태블릿·웹에서 본문이 넓어질 수 있는 최대 폭.
  static const double maxContentWidth = 600;

  /// 떠 있는 하단 메뉴에 가려지지 않도록 스크롤 끝에 두는 여백.
  static const double bottomNavClearance = 96;
}

abstract final class AppRadius {
  /// 라벨 바탕 같은 아주 작은 모서리.
  static const double xs = 3;

  /// 입력창.
  static const double input = 16;

  /// 카드.
  static const double card = 20;

  /// 버튼·칩·탭 (완전히 둥근 알약 모양).
  static const double pill = 999;
}

abstract final class AppStroke {
  static const double hairline = 1;
  static const double regular = 1.5;

  /// 강조 테두리 (입력창 오류).
  static const double strong = 2;

  static const double dash = 4;
  static const double dashGap = 3;
}
