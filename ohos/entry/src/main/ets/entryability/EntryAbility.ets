import { FlutterAbility, FlutterEngine, Log } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import PlayerPlugin from '../player/PlayerPlugin';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)

    // 三端统一定义的播放通道：app.chongyibao/player
    const plugins = flutterEngine.getPlugins()
    if (plugins != null) {
      plugins.add(new PlayerPlugin())
      Log.i('EntryAbility', 'PlayerPlugin registered')
    } else {
      Log.e('EntryAbility', 'PluginRegistry 为空，PlayerPlugin 注册失败')
    }
  }
}
