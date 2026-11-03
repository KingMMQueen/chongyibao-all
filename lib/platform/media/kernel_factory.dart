import '../../../core/config.dart';
import 'impl/native_player_kernel.dart';
import 'impl/simulated_player_kernel.dart';
import 'player_kernel.dart';

/// 播放内核工厂：全项目唯一允许决定「用哪个内核」的地方。
class PlayerKernelFactory {
  const PlayerKernelFactory._();

  static PlayerKernel create() {
    switch (AppConfig.playerKernel) {
      case 'native':
        return NativePlayerKernel();
      case 'simulated':
        return SimulatedPlayerKernel();
      default:
        throw ArgumentError(
          '未知的 PLAYER_KERNEL 配置：${AppConfig.playerKernel}，'
          '仅支持 simulated / native',
        );
    }
  }
}
