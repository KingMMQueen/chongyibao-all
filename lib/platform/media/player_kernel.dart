import 'dart:async';

import 'package:flutter/foundation.dart';

/// 播放器阶段。
enum PlayerPhase { idle, loading, ready, playing, paused, buffering, completed, error }

/// 播放器状态的唯一不可变快照。
///
/// UI 层只消费快照，不直接接触任何平台 API。
@immutable
class PlayerSnapshot {
  const PlayerSnapshot({
    this.phase = PlayerPhase.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.speed = 1.0,
    this.volume = 1.0,
    this.videoWidth = 0,
    this.videoHeight = 0,
    this.errorMessage,
  });

  static const PlayerSnapshot initial = PlayerSnapshot();

  final PlayerPhase phase;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final double speed;
  final double volume;
  final int videoWidth;
  final int videoHeight;
  final String? errorMessage;

  /// 画面宽高比；未知时回退 16:9，避免画面被拉伸。
  double get aspectRatio =>
      (videoWidth > 0 && videoHeight > 0) ? videoWidth / videoHeight : 16 / 9;

  bool get isPlaying => phase == PlayerPhase.playing;

  bool get isBusy =>
      phase == PlayerPhase.loading || phase == PlayerPhase.buffering;

  bool get hasError => phase == PlayerPhase.error;

  double get progress {
    final int total = duration.inMilliseconds;
    if (total <= 0) {
      return 0;
    }
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  double get bufferedProgress {
    final int total = duration.inMilliseconds;
    if (total <= 0) {
      return 0;
    }
    return (buffered.inMilliseconds / total).clamp(0.0, 1.0);
  }

  PlayerSnapshot copyWith({
    PlayerPhase? phase,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    double? speed,
    double? volume,
    int? videoWidth,
    int? videoHeight,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlayerSnapshot(
      phase: phase ?? this.phase,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// 播放内核抽象。
///
/// 这是三端唯一的播放契约。Android 用 Media3/ExoPlayer，iOS 用 AVPlayer，
/// 鸿蒙用 AVPlayer(OHOS)，但**都必须实现本接口**，UI 层不需要知道差异。
///
/// 实现约束：
/// 1. 任何无法支持的方法必须抛 [PlatformUnsupportedFailure]，禁止静默返回；
/// 2. 画面必须通过 Texture 输出（[textureId]），禁止使用原生视图叠层；
/// 3. 状态变化只能通过 [snapshots] 广播，不要在实现里直接回调 UI。
abstract class PlayerKernel {
  /// 内核标识，便于日志与问题定位，例如 `media3` / `avplayer` / `ohos-avplayer`。
  String get kernelName;

  /// 状态流。实现必须保证是 broadcast，且生命周期内只创建一次。
  Stream<PlayerSnapshot> get snapshots;

  /// 当前最新状态。
  PlayerSnapshot get snapshot;

  /// 供 `Texture` 组件消费的纹理 id；为 null 表示尚未准备就绪。
  int? get textureId;

  /// 打开媒体。MP4 需服务端已做 faststart 且支持 HTTP Range。
  Future<void> open(String url, {Duration startAt = Duration.zero});

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  /// 倍速播放，要求变速不变调。
  Future<void> setSpeed(double speed);

  Future<void> setVolume(double volume);

  Future<void> dispose();
}
