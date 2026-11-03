import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logger.dart';
import 'player_kernel.dart';

/// 播放控制器：UI 层唯一的播放入口。
///
/// 职责：把 [PlayerKernel] 的快照转成可监听状态、维护续播位置、做边界处理。
/// 不含任何平台判断，三端行为完全一致。
class PlayerController extends ChangeNotifier {
  PlayerController({required PlayerKernel kernel}) : _kernel = kernel {
    _snapshot = _kernel.snapshot;
    _subscription = _kernel.snapshots.listen(_onSnapshot);
  }

  /// 续播位置存储。当前为内存实现，后续替换为本地持久化即可（接口不变）。
  static final Map<String, Duration> _positionMemory = <String, Duration>{};

  static const double minSpeed = 0.5;
  static const double maxSpeed = 3.0;

  final PlayerKernel _kernel;
  late final StreamSubscription<PlayerSnapshot> _subscription;

  PlayerSnapshot _snapshot = PlayerSnapshot.initial;
  String? _currentUrl;
  bool _disposed = false;

  PlayerSnapshot get snapshot => _snapshot;
  int? get textureId => _kernel.textureId;
  String get kernelName => _kernel.kernelName;
  String? get currentUrl => _currentUrl;

  void _onSnapshot(PlayerSnapshot next) {
    _snapshot = next;
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// 打开媒体。默认从上次离开的位置续播。
  Future<void> initialize(
    String url, {
    Duration? startAt,
    bool resume = true,
  }) async {
    _currentUrl = url;
    final Duration fallback = resume
        ? (_positionMemory[url] ?? Duration.zero)
        : Duration.zero;
    AppLog.i('PlayerController', 'open $url startAt=${startAt ?? fallback}');
    await _kernel.open(url, startAt: startAt ?? fallback);
  }

  Future<void> play() => _kernel.play();

  Future<void> pause() => _kernel.pause();

  Future<void> togglePlay() async {
    final PlayerPhase phase = _snapshot.phase;
    if (phase == PlayerPhase.playing) {
      await _kernel.pause();
      return;
    }
    if (phase == PlayerPhase.ready ||
        phase == PlayerPhase.paused ||
        phase == PlayerPhase.completed) {
      await _kernel.play();
    }
  }

  Future<void> seekTo(Duration position) async {
    final Duration max = _snapshot.duration;
    Duration target = position;
    if (target < Duration.zero) {
      target = Duration.zero;
    }
    if (max > Duration.zero && target > max) {
      target = max;
    }
    await _kernel.seekTo(target);
  }

  Future<void> seekBy(Duration delta) => seekTo(_snapshot.position + delta);

  /// 按比例跳转，供自定义进度条使用（0.0 ~ 1.0）。
  Future<void> seekToProgress(double progress) {
    final Duration total = _snapshot.duration;
    if (total <= Duration.zero) {
      return Future<void>.value();
    }
    final double clamped = progress.clamp(0.0, 1.0);
    return seekTo(total * clamped);
  }

  Future<void> setSpeed(double speed) =>
      _kernel.setSpeed(speed.clamp(minSpeed, maxSpeed));

  Future<void> setVolume(double volume) =>
      _kernel.setVolume(volume.clamp(0.0, 1.0));

  /// 倍速档位循环：1.0 → 1.5 → 2.0 → 0.5 → 1.0。
  Future<void> cycleSpeed() async {
    const List<double> presets = <double>[1.0, 1.5, 2.0, 0.5];
    final int index = presets.indexOf(_snapshot.speed);
    final double next = presets[(index + 1) % presets.length];
    await setSpeed(next);
  }

  @visibleForTesting
  static void clearPositionMemory() => _positionMemory.clear();

  @override
  void dispose() {
    if (_currentUrl != null && _snapshot.position > Duration.zero) {
      _positionMemory[_currentUrl!] = _snapshot.position;
    }
    _disposed = true;
    _subscription.cancel();
    _kernel.dispose();
    super.dispose();
  }
}
