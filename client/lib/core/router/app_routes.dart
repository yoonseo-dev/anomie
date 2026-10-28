/// 경로 상수. 화면 이동은 문자열을 직접 쓰지 말고 이 값을 쓴다.
abstract final class AppRoutes {
  // 하단 메뉴 탭 (StatefulShellRoute)
  static const home = '/';
  static const map = '/map';
  static const manage = '/manage';

  /// 관리 화면의 관계 탭 (확인 기다리는 제안).
  static const manageRelations = '/manage?tab=relations';

  // 하단 메뉴 없이 위로 덮는 화면
  static const scrapNew = '/scrap/new';
  static const tagReview = '/scrap/review';
  static const conceptDetail = '/concept/:id';
  static String concept(String id) => '/concept/$id';

  // 디버그 모드 전용
  static const widgetGallery = '/dev/widgets';
}
