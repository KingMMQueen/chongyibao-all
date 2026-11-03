/// 运行期配置。所有环境相关的常量集中在此，禁止散落在业务代码里。
class AppConfig {
  const AppConfig._();

  /// 后端接口根地址。
  ///
  /// 通过 `--dart-define=API_BASE_URL=https://...` 覆盖，便于三端共用一套代码。
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com',
  );

  /// 播放器内核选择：
  /// - `simulated`：内置模拟内核，无需原生代码即可跑通全部 UI（默认）
  /// - `native`：使用三端原生播放内核（需先实现各端 MethodChannel 服务）
  static const String playerKernel = String.fromEnvironment(
    'PLAYER_KERNEL',
    defaultValue: 'simulated',
  );

  /// 演示用 MP4 地址，正式接入后端后删除。
  /// 要求：服务端已做 faststart 且支持 HTTP Range。
  static const String demoVideoUrl =
      'https://media.w3.org/2010/05/sintel/trailer.mp4';
}
