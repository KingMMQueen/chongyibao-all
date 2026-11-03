/// 全局错误模型。
///
/// 约定：任何能力缺失都必须抛出 [PlatformUnsupportedFailure]，
/// 禁止使用「静默降级」（例如返回空列表、返回 null、什么都不做）。
sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// 网络 / 服务端异常。
class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.cause, this.statusCode});

  final int? statusCode;
}

/// 平台能力未实现。必须被 UI 层捕获并明确提示用户，不允许吞掉。
class PlatformUnsupportedFailure extends AppFailure {
  const PlatformUnsupportedFailure(
    super.message, {
    required this.capability,
    required this.platform,
    super.cause,
  });

  /// 缺失的能力标识，例如 `player.setSpeed`。
  final String capability;

  /// 触发平台，例如 `ohos`。
  final String platform;

  @override
  String toString() =>
      'PlatformUnsupportedFailure($capability on $platform): $message';
}

/// 媒体资源异常（地址失效、解码失败、格式不支持等）。
class MediaFailure extends AppFailure {
  const MediaFailure(super.message, {super.cause});
}
