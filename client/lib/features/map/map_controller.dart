import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/concept_graph_repository.dart';

/// 마인드맵에서 지나온 개념 id 목록. 마지막 값이 지금 가운데 있는 개념이다.
/// 그래프를 처음 불러오면 스크랩이 가장 많은 개념 하나로 시작한다.
class MapTrailController extends Notifier<List<String>> {
  @override
  List<String> build() {
    // 그래프를 다시 불러와도(관리 화면에서 승인·삭제 등) 시작 개념이 같으면
    // 지나온 경로를 지우지 않는다.
    final start = ref.watch(
      conceptGraphProvider.select((g) => g.value?.mostScrapped?.id),
    );
    return start == null ? const [] : [start];
  }

  /// [id]를 가운데로 옮긴다. 이미 지나온 개념이면 그 지점까지 되돌아간다.
  void focus(String id) {
    final index = state.indexOf(id);
    state = index >= 0 ? state.sublist(0, index + 1) : [...state, id];
  }

  /// 한 단계 전 개념으로 돌아간다. 더 돌아갈 곳이 없으면 false.
  bool back() {
    if (state.length <= 1) return false;
    state = state.sublist(0, state.length - 1);
    return true;
  }
}

final mapTrailProvider = NotifierProvider<MapTrailController, List<String>>(
  MapTrailController.new,
);
