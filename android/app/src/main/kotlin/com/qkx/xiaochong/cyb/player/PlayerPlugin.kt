package com.qkx.xiaochong.cyb.player

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Android 播放内核：Media3 ExoPlayer + SurfaceProducer。
 *
 * 与 Dart 侧的契约见 lib/platform/media/player_channel.dart。
 *
 * 为什么用 SurfaceProducer 而不是 SurfaceTexture：
 * Flutter 3.27 在 Android 上默认启用 Impeller(Vulkan)，旧的 SurfaceTexture 外部纹理
 * 在 Impeller 下会报 "Invalid external texture" 且画面不刷新。
 * SurfaceProducer 是 Flutter 官方推荐的新纹理 API，兼容 Impeller。
 */
class PlayerPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
    private val textureRegistry: TextureRegistry,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var player: ExoPlayer? = null
    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
    private var sink: EventChannel.EventSink? = null

    private var hasSource = false
    private var hasStarted = false
    private var errorMessage: String? = null
    private var videoWidth = 0
    private var videoHeight = 0
    private var speed = 1f
    private var volume = 1f

    private val ticker = object : Runnable {
        override fun run() {
            emitState()
            mainHandler.postDelayed(this, TICK_INTERVAL_MS)
        }
    }

    private val listener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            if (playbackState == Player.STATE_READY) {
                errorMessage = null
            }
            if (playbackState == Player.STATE_ENDED) {
                mainHandler.removeCallbacks(ticker)
            }
            emitState()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (isPlaying) {
                hasStarted = true
                mainHandler.removeCallbacks(ticker)
                mainHandler.post(ticker)
            } else {
                mainHandler.removeCallbacks(ticker)
            }
            emitState()
        }

        override fun onVideoSizeChanged(videoSize: VideoSize) {
            videoWidth = videoSize.width
            videoHeight = videoSize.height
            if (videoWidth > 0 && videoHeight > 0) {
                // 让纹理缓冲区和视频像素比例一致，否则画面会被压缩
                surfaceProducer?.setSize(videoWidth, videoHeight)
            }
            emitState()
        }

        override fun onPlayerError(error: PlaybackException) {
            errorMessage = error.errorCodeName + ": " + (error.message ?: "")
            Log.e(TAG, "playback error: $errorMessage", error)
            mainHandler.removeCallbacks(ticker)
            emitState()
        }
    }

    fun attach() {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun detach() {
        releasePlayer()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        sink = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        emitState()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> result.success(createPlayerWithTexture())
            "setSource" -> {
                val url = call.argument<String>("url")
                val startMs =
                    (call.argument<Any>("startPositionMs") as? Number)?.toLong() ?: 0L
                if (url.isNullOrEmpty()) {
                    result.error("bad_args", "url 为空", null)
                    return
                }
                setSource(url, startMs)
                result.success(null)
            }
            "play" -> {
                hasStarted = true
                player?.play()
                result.success(null)
            }
            "pause" -> {
                player?.pause()
                result.success(null)
            }
            "seekTo" -> {
                val ms = (call.argument<Any>("positionMs") as? Number)?.toLong() ?: 0L
                player?.seekTo(ms)
                emitState()
                result.success(null)
            }
            "setSpeed" -> {
                val value = (call.argument<Any>("speed") as? Number)?.toFloat() ?: 1f
                speed = value
                // pitch 固定 1f：变速不变调
                player?.playbackParameters = PlaybackParameters(value, 1f)
                emitState()
                result.success(null)
            }
            "setVolume" -> {
                val value = (call.argument<Any>("volume") as? Number)?.toFloat() ?: 1f
                volume = value
                player?.volume = value
                emitState()
                result.success(null)
            }
            "dispose" -> {
                releasePlayer()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun createPlayerWithTexture(): Long {
        releasePlayer()

        val producer = textureRegistry.createSurfaceProducer()
        surfaceProducer = producer
        producer.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
            override fun onSurfaceCreated() {
                Log.i(TAG, "surface created")
                player?.setVideoSurface(producer.getSurface())
            }

            override fun onSurfaceAvailable() {
                Log.i(TAG, "surface available")
                player?.setVideoSurface(producer.getSurface())
            }

            override fun onSurfaceDestroyed() {
                Log.i(TAG, "surface destroyed")
                player?.setVideoSurface(null)
            }
        })

        val exoPlayer = ExoPlayer.Builder(context).build()
        exoPlayer.setVideoSurface(producer.getSurface())
        exoPlayer.addListener(listener)
        player = exoPlayer

        errorMessage = null
        Log.i(TAG, "player created, textureId=${producer.id()}")
        return producer.id()
    }

    private fun setSource(url: String, startMs: Long) {
        val exoPlayer = player ?: run {
            createPlayerWithTexture()
            player!!
        }
        hasSource = true
        errorMessage = null
        Log.i(TAG, "open source: $url startAt=$startMs")
        exoPlayer.setMediaItem(MediaItem.fromUri(url))
        exoPlayer.prepare()
        if (startMs > 0L) {
            exoPlayer.seekTo(startMs)
        }
        emitState()
    }

    private fun releasePlayer() {
        mainHandler.removeCallbacks(ticker)
        player?.removeListener(listener)
        player?.release()
        player = null
        surfaceProducer?.release()
        surfaceProducer = null
        hasSource = false
        hasStarted = false
    }

    private fun emitState() {
        val exoPlayer = player
        val payload = HashMap<String, Any?>()
        payload["phase"] = currentPhase()
        payload["positionMs"] = exoPlayer?.currentPosition ?: 0L
        payload["durationMs"] = exoPlayer?.duration?.takeIf { it != C.TIME_UNSET } ?: 0L
        payload["bufferedMs"] = exoPlayer?.bufferedPosition ?: 0L
        payload["speed"] = speed.toDouble()
        payload["volume"] = volume.toDouble()
        payload["videoWidth"] = videoWidth
        payload["videoHeight"] = videoHeight
        payload["errorMessage"] = errorMessage
        sink?.success(payload)
    }

    private fun currentPhase(): String {
        val exoPlayer = player ?: return "idle"
        if (errorMessage != null) {
            return "error"
        }
        if (!hasSource) {
            return "idle"
        }
        return when (exoPlayer.playbackState) {
            Player.STATE_IDLE -> "loading"
            Player.STATE_BUFFERING -> "buffering"
            Player.STATE_READY -> when {
                exoPlayer.playWhenReady -> "playing"
                !hasStarted -> "ready"
                else -> "paused"
            }
            Player.STATE_ENDED -> "completed"
            else -> "idle"
        }
    }

    private companion object {
        const val TAG = "PlayerPlugin"
        const val METHOD_CHANNEL = "app.chongyibao/player"
        const val EVENT_CHANNEL = "app.chongyibao/player/events"
        const val TICK_INTERVAL_MS = 200L
    }
}
