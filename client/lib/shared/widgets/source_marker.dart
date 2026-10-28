import 'package:flutter/widgets.dart';

import '../../core/theme/app_colors.dart';
import '../models/scrap.dart';

/// 출처 앞의 작은 표시. 기사는 꽉 찬 사각형, 책은 빈 세로 사각형.
class SourceMarker extends StatelessWidget {
  const SourceMarker({
    super.key,
    required this.source,
    this.color = AppColors.black,
  });

  final ScrapSource source;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return switch (source) {
      ScrapSource.article => SizedBox.square(
        dimension: 7,
        child: ColoredBox(color: color),
      ),
      ScrapSource.book => Container(
        width: 6,
        height: 9,
        decoration: BoxDecoration(border: Border.all(color: color)),
      ),
    };
  }
}
