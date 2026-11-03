import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../../core/failure.dart';
import '../../../core/logger.dart';
import '../player_channel.dart';
import '../player_kernel.dart';

/// 三端共用的原生播放内核 Dart 侧实现。
///
/// 原生侧（Kotlin / Swift / ArkTS）只需按 [PlayerChannelSpec] 注册同名通道，
/// Dart 侧代码完全一致，无需为鸿蒙单独写一份。
class NativePlayerKernel implements PlayerKernel {
  NativePlayerKernel({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    String? platformName,
  })  : _method =
            methodChannel ?? const MethodChannel(PlayerChannelSpec.method),
        _events = eventChannel ?? const EventChannel(PlayerChannelSpec.event),
        _platform = platformName ?? Platform.operatingSystem;

  final MethodChannel _method;
  final EventChannel _events;
  final String _platform;

  final StreamController<PlayerSnapshot> _snapshots =
      StreamController<PlayerSnapshot>.broadcast();

  PlayerSnapshot _snapshot = PlayerSnapshot.initial;
  StreamSubscription<dynamic>? _eventSubscription;
  int? _textureId;
  bool _disposed = false;

  @override
  String get kernelName => 'native:$_platform';

  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  int? get textureId => _textureId;

  void _emit(PlayerSnapshot next) {
    if (_disposed) {
      return;
    }
    _snapshot = next;
    if (!_snapshots.isClosed) {
      _snapshots.add(next);
    }
  }

  /// 统一处理「原生未实现」：显式失败，不做静默降级。
  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _method.invokeMethod<T>(method, args);
    } on MissingPluginException catch (error, stackTrace) {
      AppLog.e('NativePlayerKernel', '原生方法未实现: $method', error, stackTrace);
      throw PlatformUnsupportedFailure(
        '当前平台未实现播放器能力：$method',
        capability: 'player.$method',
        platform: _platform,
        cause: error,
      );
    } on PlatformException catch (error, stackTrace) {
      AppLog.e('NativePlayerKernel', '原生方法失败: $method', error, stackTrace);
      throw MediaFailure('播放器调用失败：${error.message}', cause: error);
    }
  }

  void _listenEvents() {
    _eventSubscription ??= _events.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          _emit(_mapEvent(event));
        }
      },
      onError: (Object error) {
        AppLog.e('NativePlayerKernel', '播放器事件流异常', error);
        _emit(
          _snapshot.copyWith(
            phase: PlayerPhase.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  PlayerSnapshot _mapEvent(Map<dynamic, dynamic> event) {
    final String rawPhase =
        event[PlayerChannelSpec.fPhase] as String? ?? PlayerPhase.idle.name;
    final PlayerPhase phase = PlayerPhase.values.firstWhere(
      (PlayerPhase p) => p.name == rawPhase,
      orElse: () => PlayerPhase.idle,
    );
    return PlayerSnapshot(
      phase: phase,
      position: Duration(
        milliseconds: (event[PlayerChannelSpec.fPositionMs] as int?) ?? 0,
      ),
      duration: Duration(
        milliseconds: (event[PlayerChannelSpec.fDurationMs] as int?) ?? 0,
      ),
      buffered: Duration(
        milliseconds: (event[PlayerChannelSpec.fBufferedMs] as int?) ?? 0,
      ),
      speed: (event[PlayerChannelSpec.fSpeed] as num?)?.toDouble() ??
          _snapshot.speed,
      volume: (event[PlayerChannelSpec.fVolume] as num?)?.toDouble() ??
          _snapshot.volume,
      videoWidth: (event[PlayerChannelSpec.fVideoWidth] as num?)?.toInt() ?? 0,
      videoHeight:
          (event[PlayerChannelSpec.fVideoHeight] as num?)?.toInt() ?? 0,
      errorMessage: event[PlayerChannelSpec.fErrorMessage] as String?,
    );
  }

  @override
  Future<void> open(String url, {Duration startAt = Duration.zero}) async {
    _emit(
      _snapshot.copyWith(phase: PlayerPhase.loading, clearError: true),
    );
    final int? textureId = await _invoke<int>(PlayerChannelSpec.mCreate);
    _textureId = textureId;
    _listenEvents();
    await _invoke<void>(PlayerChannelSpec.mSetSource, <String, dynamic>{
      PlayerChannelSpec.fUrl: url,
      PlayerChannelSpec.fStartPositionMs: startAt.inMilliseconds,
    });
  }

  @override
  Future<void> play() => _invoke<void>(PlayerChannelSpec.mPlay);

  @override
  Future<void> pause() => _invoke<void>(PlayerChannelSpec.mPause);

  @override
  Future<void> seekTo(Duration position) => _invoke<void>(
        PlayerChannelSpec.mSeekTo,
        <String, dynamic>{PlayerChannelSpec.fPositionMs: position.inMilliseconds},
      );

  @override
  Future<void> setSpeed(double speed) => _invoke<void>(
        PlayerChannelSpec.mSetSpeed,
        <String, dynamic>{PlayerChannelSpec.fSpeed: speed},
      );

  @override
  Future<void> setVolume(double volume) => _invoke<void>(
        PlayerChannelSpec.mSetVolume,
        <String, dynamic>{PlayerChannelSpec.fVolume: volume},
      );

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    try {
      await _method.invokeMethod<void>(PlayerChannelSpec.mDispose);
    } on MissingPluginException {
      // 未实现时无需处理，属于正常退出路径。
    }
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    if (!_snapshots.isClosed) {
      await _snapshots.close();
    }
  }
}
