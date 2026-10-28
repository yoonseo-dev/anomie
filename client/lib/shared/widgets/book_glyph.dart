import 'package:flutter/widgets.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// 책 표지와 책등 아이콘 (Figma 14:77). 40×40 안에 그린다.
class BookGlyph extends StatelessWidget {
  const BookGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: Center(
        child: Container(
          width: 26,
          height: 32,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.black,
              width: AppStroke.regular,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 4.5),
          child: const SizedBox(
            width: AppStroke.regular,
            height: double.infinity,
            child: ColoredBox(color: AppColors.black),
          ),
        ),
      ),
    );
  }
}
