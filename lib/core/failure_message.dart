import 'failure.dart';

/// 把任意异常转成可直接展示给用户的文案。
///
/// 平台能力缺失（[PlatformUnsupportedFailure]）必须被明确提示，
/// 不允许吞掉后按「无数据」处理。
String describeFailure(Object error) {
  if (error is PlatformUnsupportedFailure) {
    return '${error.capability} 在 ${error.platform} 上尚未实现';
  }
  if (error is AppFailure) {
    return error.message;
  }
  return error.toString();
}
