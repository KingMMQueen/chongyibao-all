import 'dart:developer' as developer;

/// 统一日志出口。
///
/// 三端（尤其 iOS）在无本地 Mac 时看不到控制台输出，日志最终会通过
/// [AppLog.sink] 转发到远程监控（Sentry / Crashlytics）。接入远程监控时
/// 只需替换 [AppLog.sink]，不要在各处直接调用 print。
class AppLog {
  const AppLog._();

  /// 远程日志出口，由 main.dart 在启动时注入。
  static void Function(String level, String tag, String message, Object? error)? sink;

  static void d(String tag, String message) {
    developer.log(message, name: tag, level: 500);
    sink?.call('debug', tag, message, null);
  }

  static void i(String tag, String message) {
    developer.log(message, name: tag, level: 800);
    sink?.call('info', tag, message, null);
  }

  static void w(String tag, String message, [Object? error]) {
    developer.log(message, name: tag, level: 900, error: error);
    sink?.call('warn', tag, message, error);
  }

  static void e(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(message, name: tag, level: 1000, error: error, stackTrace: stackTrace);
    sink?.call('error', tag, message, error);
  }
}
