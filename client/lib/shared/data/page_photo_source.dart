import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/scrap_analysis.dart';

/// 책 페이지 사진을 어디서 가져올지.
enum PhotoOrigin { camera, gallery }

/// 책 페이지 사진을 가져온다. 사용자가 취소하면 null.
abstract interface class PagePhotoSource {
  Future<PagePhoto?> pick(PhotoOrigin origin);
}

/// 기기 카메라·앨범 (`image_picker`). 웹에서는 둘 다 파일 고르기 창이 열린다.
class DevicePagePhotoSource implements PagePhotoSource {
  DevicePagePhotoSource([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// 긴 변 상한. 서버는 1000px 이상을 요구하고(작은 글자 인식), 7MB 이하만 받는다.
  static const maxSide = 2400.0;

  @override
  Future<PagePhoto?> pick(PhotoOrigin origin) async {
    final file = await _picker.pickImage(
      source: origin == PhotoOrigin.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: 85,
    );
    if (file == null) return null;
    return PagePhoto(bytes: await file.readAsBytes(), name: file.name);
  }
}

final pagePhotoSourceProvider = Provider<PagePhotoSource>(
  (ref) => DevicePagePhotoSource(),
);
