import 'package:chongyibao/platform/media/impl/simulated_player_kernel.dart';
import 'package:chongyibao/platform/media/player_controller.dart';
import 'package:chongyibao/platform/media/player_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// 广播流的下一次投递是异步的，等待一个事件循环让监听器同步状态。
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(PlayerController.clearPositionMemory);

  test('播放状态机：打开 -> 播放 -> 定位 -> 倍速 -> 暂停', () async {
    final SimulatedPlayerKernel kernel =
        SimulatedPlayerKernel(duration: const Duration(seconds: 30));
    final PlayerController controller = PlayerController(kernel: kernel);

    await controller.initialize('demo://a');
    await settle();
    expect(controller.snapshot.phase, PlayerPhase.ready);
    expect(controller.snapshot.duration, const Duration(seconds: 30));

    await controller.play();
    await settle();
    expect(controller.snapshot.phase, PlayerPhase.playing);

    await controller.seekToProgress(0.5);
    await settle();
    expect(controller.snapshot.position, const Duration(seconds: 15));

    await controller.cycleSpeed();
    await settle();
    expect(controller.snapshot.speed, 1.5);

    await controller.seekBy(const Duration(seconds: 100));
    await settle();
    expect(controller.snapshot.position, const Duration(seconds: 30));

    await controller.togglePlay();
    await settle();
    expect(controller.snapshot.phase, PlayerPhase.paused);

    controller.dispose();
  });

  test('续播：退出后重新打开从上次位置开始', () async {
    final PlayerController first = PlayerController(
      kernel: SimulatedPlayerKernel(duration: const Duration(seconds: 60)),
    );
    await first.initialize('demo://resume');
    await settle();
    await first.seekTo(const Duration(seconds: 12));
    await settle();
    first.dispose();
    await settle();

    final PlayerController second = PlayerController(
      kernel: SimulatedPlayerKernel(duration: const Duration(seconds: 60)),
    );
    await second.initialize('demo://resume');
    await settle();
    expect(second.snapshot.position, const Duration(seconds: 12));

    second.dispose();
  });

  test('关闭续播时从头开始', () async {
    final PlayerController first = PlayerController(
      kernel: SimulatedPlayerKernel(duration: const Duration(seconds: 60)),
    );
    await first.initialize('demo://fresh');
    await settle();
    await first.seekTo(const Duration(seconds: 20));
    await settle();
    first.dispose();
    await settle();

    final PlayerController second = PlayerController(
      kernel: SimulatedPlayerKernel(duration: const Duration(seconds: 60)),
    );
    await second.initialize('demo://fresh', resume: false);
    await settle();
    expect(second.snapshot.position, Duration.zero);

    second.dispose();
  });
}
