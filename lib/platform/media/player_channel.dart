/// 三端原生播放器与 Dart 侧的通道契约。
///
/// 一段 Dart 代码，三份原生实现（Kotlin / Swift / ArkTS），注册**同名**通道。
///
/// ---------------------------------------------------------------
/// MethodChannel: `app.chongyibao/player`
/// ---------------------------------------------------------------
/// | 方法        | 入参                                  | 返回          |
/// |-------------|---------------------------------------|---------------|
/// | create      | 无                                    | int textureId |
/// | setSource   | {url: String, startPositionMs: int}   | null          |
/// | play        | 无                                    | null          |
/// | pause       | 无                                    | null          |
/// | seekTo      | {positionMs: int}                     | null          |
/// | setSpeed    | {speed: double}                       | null          |
/// | setVolume   | {volume: double 0~1}                  | null          |
/// | dispose     | 无                                    | null          |
///
/// ---------------------------------------------------------------
/// EventChannel: `app.chongyibao/player/events`
/// ---------------------------------------------------------------
/// 原生侧持续发送 Map：
/// ```
/// {
///   "phase": "idle|loading|ready|playing|paused|buffering|completed|error",
///   "positionMs": int,
///   "durationMs": int,
///   "bufferedMs": int,
///   "speed": double,
///   "volume": double,
///   "videoWidth": int,        // 0 表示未知
///   "videoHeight": int,
///   "errorMessage": String?   // 仅 error 阶段
/// }
/// ```
///
/// ---------------------------------------------------------------
/// 三端内核对应关系（原生侧实现要点）
/// ---------------------------------------------------------------
/// - Android：`androidx.media3.exoplayer.ExoPlayer` + `SurfaceTexture`；
///   倍速用 `PlaybackParameters(speed, pitch = 1f)` 保证不变调。
/// - iOS：`AVPlayer` + `AVPlayerItemVideoOutput` 输出 CVPixelBuffer 到
///   `FlutterTexture`；倍速用 `AVPlayerItem.audioTimePitchAlgorithm`。
/// - HarmonyOS：`@ohos.multimedia.media` 的 `AVPlayer` + `XComponent` 的
///   NativeWindow 输出到 `FlutterTexture`；倍速用 `AVPlayer.setSpeed`。
///
/// 三端都必须处理：进入后台时的暂停策略、音频焦点、锁屏控制（后续迭代）。
class PlayerChannelSpec {
  const PlayerChannelSpec._();

  static const String method = 'app.chongyibao/player';
  static const String event = 'app.chongyibao/player/events';

  static const String mCreate = 'create';
  static const String mSetSource = 'setSource';
  static const String mPlay = 'play';
  static const String mPause = 'pause';
  static const String mSeekTo = 'seekTo';
  static const String mSetSpeed = 'setSpeed';
  static const String mSetVolume = 'setVolume';
  static const String mDispose = 'dispose';

  static const String fUrl = 'url';
  static const String fStartPositionMs = 'startPositionMs';
  static const String fPositionMs = 'positionMs';
  static const String fDurationMs = 'durationMs';
  static const String fBufferedMs = 'bufferedMs';
  static const String fSpeed = 'speed';
  static const String fVolume = 'volume';
  static const String fPhase = 'phase';
  static const String fVideoWidth = 'videoWidth';
  static const String fVideoHeight = 'videoHeight';
  static const String fErrorMessage = 'errorMessage';
}
