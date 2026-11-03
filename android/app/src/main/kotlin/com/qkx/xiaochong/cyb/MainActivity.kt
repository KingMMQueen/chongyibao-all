package com.qkx.xiaochong.cyb

import com.qkx.xiaochong.cyb.player.PlayerPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var playerPlugin: PlayerPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val plugin = PlayerPlugin(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
            flutterEngine.renderer,
        )
        plugin.attach()
        playerPlugin = plugin
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        playerPlugin?.detach()
        playerPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
