import 'dart:async';

import 'package:flutter/foundation.dart';

import '../player_kernel.dart';

/// 纯 Dart 模拟内核：不依赖任何原生代码，用于 UI 开发、联调与自动化测试。
///
/// 正式环境通过 `--dart-define=PLAYER_KERNEL=native` 切换到原生内核。
/// 它的存在让「UI 层」可以独立于「原生实现进度」先行开发和验收。
class SimulatedPlayerKernel implements PlayerKernel {
  SimulatedPlayerKernel({
    this.duration = const Duration(seconds: 52),
    this.tick = const Duration(milliseconds: 200),
  });

  final Duration duration;
  final Duration tick;

  final StreamController<PlayerSnapshot> _controller =
      StreamController<PlayerSnapshot>.broadcast();

  PlayerSnapshot _snapshot = PlayerSnapshot.initial;
  Timer? _timer;
  bool _disposed = false;

  @override
  String get kernelName => 'simulated';

  @override
  Stream<PlayerSnapshot> get snapshots => _controller.stream;

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  int? get textureId => null;

  void _emit(PlayerSnapshot next) {
    if (_disposed) {
      return;
    }
    _snapshot = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
  }

  @override
  Future<void> open(String url, {Duration startAt = Duration.zero}) async {
    _emit(PlayerSnapshot(phase: PlayerPhase.loading, duration: duration));
    await Future<void>.delayed(tick);
    _emit(
      PlayerSnapshot(
        phase: PlayerPhase.ready,
        duration: duration,
        position: _clamp(startAt),
      ),
    );
  }

  @override
  Future<void> play() async {
    if (_snapshot.phase == PlayerPhase.completed) {
      _emit(_snapshot.copyWith(phase: PlayerPhase.ready, position: Duration.zero));
    }
    _emit(_snapshot.copyWith(phase: PlayerPhase.playing, clearError: true));
    _startTimer();
  }

  @override
  Future<void> pause() async {
    _stopTimer();
    _emit(_snapshot.copyWith(phase: PlayerPhase.paused));
  }

  @override
  Future<void> seekTo(Duration position) async {
    _emit(_snapshot.copyWith(position: _clamp(position)));
  }

  @override
  Future<void> setSpeed(double speed) async {
    _emit(_snapshot.copyWith(speed: speed.clamp(0.5, 3.0)));
  }

  @override
  Future<void> setVolume(double volume) async {
    _emit(_snapshot.copyWith(volume: volume.clamp(0.0, 1.0)));
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(tick, (Timer _) {
      final Duration next = _snapshot.position + tick * _snapshot.speed;
      if (next >= duration) {
        _stopTimer();
        _emit(
          _snapshot.copyWith(
            phase: PlayerPhase.completed,
            position: duration,
            buffered: duration,
          ),
        );
        return;
      }
      _emit(
        _snapshot.copyWith(
          position: next,
          buffered: next + const Duration(seconds: 8),
        ),
      );
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Duration _clamp(Duration value) {
    if (value < Duration.zero) {
      return Duration.zero;
    }
    if (value > duration) {
      return duration;
    }
    return value;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _stopTimer();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}

/// 便于测试断言：把快照转换成可比较的字符串。
@visibleForTesting
String describeSnapshot(PlayerSnapshot snapshot) {
  return '${snapshot.phase.name}@${snapshot.position.inMilliseconds}'
      '/${snapshot.duration.inMilliseconds}'
      'x${snapshot.speed.toStringAsFixed(2)}';
}
