import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../core/failure.dart';
import '../../core/logger.dart';

/// 选择结果。只传路径，字节内容留在原生侧处理，避免大图跨通道拷贝。
class PickedImage {
  const PickedImage({
    required this.path,
    this.width,
    this.height,
    this.byteSize,
  });

  final String path;
  final int? width;
  final int? height;
  final int? byteSize;

  factory PickedImage.fromMap(Map<dynamic, dynamic> map) {
    return PickedImage(
      path: map['path'] as String,
      width: map['width'] as int?,
      height: map['height'] as int?,
      byteSize: map['byteSize'] as int?,
    );
  }
}

/// 图片选择 / 拍照 / 压缩。
///
/// 原生通道契约（三端注册同名通道 `app.chongyibao/image_picker`）：
///
/// | 方法       | 入参                                              | 返回 |
/// |------------|---------------------------------------------------|------|
/// | pickImages | {maxCount: int}                                   | List<Map{path,width,height,byteSize}> |
/// | takePhoto  | 无                                                | Map 同上 |
/// | compress   | {path, maxLongSide: int, quality: int 0~100}      | Map 同上 |
///
/// 原生实现要点：
/// - Android：Photo Picker + `BitmapFactory.inSampleSize` 降采样 + JPEG 重编码
/// - iOS：PHPickerViewController + `CGImageSourceCreateThumbnailAtIndex`
/// - HarmonyOS：`@ohos.file.photoAccessHelper` + `image.createImageSource` 的 desiredSize
class ImagePickService {
  ImagePickService({MethodChannel? channel, String? platformName})
      : _channel = channel ?? const MethodChannel(channelName),
        _platform = platformName ?? Platform.operatingSystem;

  static const String channelName = 'app.chongyibao/image_picker';
  static const String mPickImages = 'pickImages';
  static const String mTakePhoto = 'takePhoto';
  static const String mCompress = 'compress';

  final MethodChannel _channel;
  final String _platform;

  Future<T> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      final T? result = await _channel.invokeMethod<T>(method, args);
      if (result == null) {
        throw PlatformUnsupportedFailure(
          '图片能力返回空结果：$method',
          capability: 'image.$method',
          platform: _platform,
        );
      }
      return result;
    } on MissingPluginException catch (error, stackTrace) {
      AppLog.e('ImagePickService', '原生图片能力未实现: $method', error, stackTrace);
      throw PlatformUnsupportedFailure(
        '当前平台未实现图片能力：$method',
        capability: 'image.$method',
        platform: _platform,
        cause: error,
      );
    } on PlatformException catch (error, stackTrace) {
      AppLog.e('ImagePickService', '原生图片能力失败: $method', error, stackTrace);
      throw MediaFailure('图片操作失败：${error.message}', cause: error);
    }
  }

  /// 从相册多选，上限 [maxCount]。
  Future<List<PickedImage>> pickImages({int maxCount = 9}) async {
    final List<dynamic> raw = await _invoke<List<dynamic>>(
      mPickImages,
      <String, dynamic>{'maxCount': maxCount},
    );
    return raw
        .map((dynamic e) => PickedImage.fromMap(e as Map<dynamic, dynamic>))
        .toList(growable: false);
  }

  /// 调用相机拍照。
  Future<PickedImage> takePhoto() async {
    final Map<dynamic, dynamic> raw =
        await _invoke<Map<dynamic, dynamic>>(mTakePhoto);
    return PickedImage.fromMap(raw);
  }

  /// 压缩到最长边 [maxLongSide]，质量 [quality]（0~100）。
  Future<PickedImage> compress(
    String path, {
    int maxLongSide = 1920,
    int quality = 85,
  }) async {
    final Map<dynamic, dynamic> raw =
        await _invoke<Map<dynamic, dynamic>>(mCompress, <String, dynamic>{
      'path': path,
      'maxLongSide': maxLongSide,
      'quality': quality,
    });
    return PickedImage.fromMap(raw);
  }
}
