import {
  Any,
  EventChannel,
  EventSink,
  FlutterPlugin,
  FlutterPluginBinding,
  Log,
  MethodCall,
  MethodChannel,
  MethodCallHandler,
  MethodResult,
  StreamHandler,
  SurfaceTextureEntry,
  TextureRegistry
} from '@ohos/flutter_ohos';
import media from '@ohos.multimedia.media';
import { BusinessError } from '@ohos.base';

const TAG = 'PlayerPlugin';
const METHOD_CHANNEL = 'app.chongyibao/player';
const EVENT_CHANNEL = 'app.chongyibao/player/events';

/**
 * 鸿蒙播放内核：AVPlayer + Flutter 纹理。
 *
 * 与 Dart 侧的契约见 lib/platform/media/player_channel.dart。
 *
 * 画面通路：
 *   TextureRegistry.getTextureId() -> registerTexture() -> SurfaceTextureEntry.getSurfaceId()
 *   -> 赋给 AVPlayer.surfaceId，由 AVPlayer 直接解码到该 surface，
 *   引擎侧自动刷新纹理，Dart 侧用 Texture(textureId:) 消费。
 */
class OhosPlayerKernel {
  private avPlayer: media.AVPlayer | null = null;
  private entry: SurfaceTextureEntry | null = null;
  private textureId: number = -1;
  private hasSource: boolean = false;
  private hasStarted: boolean = false;
  private errorMessage: string = '';
  private videoWidth: number = 0;
  private videoHeight: number = 0;
  private speed: number = 1.0;
  private volume: number = 1.0;
  // prepare 完成后再执行的起播位置
  private pendingStartMs: number = 0;

  private readonly registry: TextureRegistry;
  private readonly onState: (payload: Map<string, Object>) => void;

  constructor(registry: TextureRegistry, onState: (payload: Map<string, Object>) => void) {
    this.registry = registry;
    this.onState = onState;
  }

  async create(): Promise<number> {
    this.release();
    const textureId: number = this.registry.getTextureId();
    const entry: SurfaceTextureEntry = this.registry.registerTexture(textureId);
    this.textureId = textureId;
    this.entry = entry;

    const player: media.AVPlayer = await media.createAVPlayer();
    this.avPlayer = player;
    this.registerEvents(player);
    this.hasSource = false;
    this.hasStarted = false;
    this.errorMessage = '';
    Log.i(TAG, `player created, textureId=${textureId}`);
    return textureId;
  }

  private registerEvents(player: media.AVPlayer): void {
    player.on('stateChange', (state: media.AVPlayerState) => {
      Log.i(TAG, `stateChange: ${state}`);
      if (state === 'initialized') {
        // url 赋值是异步的：必须等进入 initialized 才能设置 surfaceId 并 prepare，
        // 否则会报 "Prepare operation only supports stopped/initialized"。
        if (this.entry != null) {
          player.surfaceId = this.entry.getSurfaceId().toString();
        }
        try {
          player.prepare();
        } catch (error) {
          this.fail(`prepare: ${(error as BusinessError).message}`);
        }
      } else if (state === 'prepared') {
        this.speed = 1.0;
        this.volume = 1.0;
        player.setVolume(this.volume);
        if (this.pendingStartMs > 0) {
          const target: number = this.pendingStartMs;
          this.pendingStartMs = 0;
          try {
            player.seek(target, media.SeekMode.SEEK_CLOSEST);
          } catch (error) {
            Log.e(TAG, `seek failed: ${(error as BusinessError).message}`);
          }
        }
      }
      this.emitState();
    });

    player.on('timeUpdate', (time: number) => {
      this.emitState();
    });

    player.on('videoSizeChange', (width: number, height: number) => {
      this.videoWidth = width;
      this.videoHeight = height;
      if (width > 0 && height > 0) {
        this.registry.setTextureBufferSize(this.textureId, width, height);
      }
      this.emitState();
    });

    player.on('error', (error: BusinessError) => {
      this.errorMessage = `${error.code}: ${error.message}`;
      Log.e(TAG, `playback error: ${this.errorMessage}`);
      this.emitState();
    });
  }

  async setSource(url: string, startMs: number): Promise<void> {
    if (this.avPlayer == null || this.entry == null) {
      throw new Error('player 未创建，请先调用 create');
    }
    this.hasSource = true;
    this.errorMessage = '';
    this.pendingStartMs = startMs;
    Log.i(TAG, `open source: ${url} startAt=${startMs}`);
    // 赋值 url 会异步触发 stateChange -> initialized，
    // 设置 surfaceId、prepare、seek 都在状态回调里继续。
    this.avPlayer.url = url;
  }

  private fail(message: string): void {
    this.errorMessage = message;
    Log.e(TAG, message);
    this.emitState();
  }

  async play(): Promise<void> {
    this.hasStarted = true;
    await this.avPlayer?.play();
    this.emitState();
  }

  async pause(): Promise<void> {
    await this.avPlayer?.pause();
    this.emitState();
  }

  async seekTo(positionMs: number): Promise<void> {
    await this.avPlayer?.seek(positionMs, media.SeekMode.SEEK_CLOSEST);
    this.emitState();
  }

  async setSpeed(speed: number): Promise<void> {
    this.speed = speed;
    await this.avPlayer?.setSpeed(speed);
    this.emitState();
  }

  async setVolume(volume: number): Promise<void> {
    this.volume = volume;
    await this.avPlayer?.setVolume(volume);
    this.emitState();
  }

  emitNow(): void {
    this.emitState();
  }

  private currentPhase(): string {
    const player = this.avPlayer;
    if (player == null) {
      return 'idle';
    }
    if (this.errorMessage.length > 0) {
      return 'error';
    }
    if (!this.hasSource) {
      return 'idle';
    }
    switch (player.state) {
      case 'idle':
        return 'loading';
      case 'initialized':
        return 'loading';
      case 'prepared':
        return this.hasStarted ? 'paused' : 'ready';
      case 'playing':
        return 'playing';
      case 'paused':
        return 'paused';
      case 'completed':
        return 'completed';
      case 'error':
        return 'error';
      default:
        return 'idle';
    }
  }

  private emitState(): void {
    const player = this.avPlayer;
    const payload = new Map<string, Object>();
    payload.set('phase', this.currentPhase());
    payload.set('positionMs', player != null ? player.currentTime : 0);
    payload.set('durationMs', this.durationMs());
    // AVPlayer 不暴露缓冲位置，MP4 渐进下载场景下按已就绪处理
    payload.set('bufferedMs', this.durationMs());
    payload.set('speed', this.speed);
    payload.set('volume', this.volume);
    payload.set('videoWidth', this.videoWidth);
    payload.set('videoHeight', this.videoHeight);
    payload.set('errorMessage', this.errorMessage);
    this.onState(payload);
  }

  private durationMs(): number {
    const player = this.avPlayer;
    if (player == null) {
      return 0;
    }
    const duration: number = player.duration;
    if (duration === undefined || duration === null || duration < 0) {
      return 0;
    }
    return duration;
  }

  release(): void {
    if (this.avPlayer != null) {
      this.avPlayer.release();
      this.avPlayer = null;
    }
    if (this.entry != null) {
      this.registry.unregisterTexture(this.textureId);
      this.entry = null;
    }
    this.hasSource = false;
    this.hasStarted = false;
    this.errorMessage = '';
  }
}

/**
 * 鸿蒙端播放器插件。三端注册同名通道，Dart 侧代码完全一致。
 */
export default class PlayerPlugin implements FlutterPlugin, MethodCallHandler, StreamHandler {
  private kernel: OhosPlayerKernel | null = null;
  private methodChannel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private sink: EventSink | null = null;

  getUniqueClassName(): string {
    return 'PlayerPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.kernel = new OhosPlayerKernel(
      binding.getTextureRegistry(),
      (payload: Map<string, Object>) => {
        if (this.sink != null) {
          this.sink.success(payload);
        }
      }
    );

    const messenger = binding.getBinaryMessenger();
    this.methodChannel = new MethodChannel(messenger, METHOD_CHANNEL);
    this.methodChannel.setMethodCallHandler(this);
    this.eventChannel = new EventChannel(messenger, EVENT_CHANNEL);
    this.eventChannel.setStreamHandler(this);
    Log.i(TAG, 'player plugin attached');
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.methodChannel?.setMethodCallHandler(null);
    this.eventChannel?.setStreamHandler(null);
    this.kernel?.release();
    this.kernel = null;
    this.sink = null;
  }

  onListen(args: Any, events: EventSink): void {
    this.sink = events;
    this.kernel?.emitNow();
  }

  onCancel(args: Any): void {
    this.sink = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    const kernel = this.kernel;
    if (kernel == null) {
      result.error('not_attached', '播放插件未初始化', null);
      return;
    }

    switch (call.method) {
      case 'create':
        kernel.create()
          .then((textureId: number) => result.success(textureId))
          .catch((error: BusinessError) => {
            Log.e(TAG, `create failed: ${error.message}`);
            result.error('create_failed', error.message, null);
          });
        break;

      case 'setSource': {
        const url = call.argument('url') as string;
        const startMs = call.argument('startPositionMs') as number;
        if (url === undefined || url === null || url.length === 0) {
          result.error('bad_args', 'url 为空', null);
          return;
        }
        kernel.setSource(url, startMs === undefined ? 0 : startMs)
          .then(() => result.success(null))
          .catch((error: BusinessError) => {
            Log.e(TAG, `setSource failed: ${error.message}`);
            result.error('source_failed', error.message, null);
          });
        break;
      }

      case 'play':
        kernel.play()
          .then(() => result.success(null))
          .catch((error: BusinessError) => result.error('play_failed', error.message, null));
        break;

      case 'pause':
        kernel.pause()
          .then(() => result.success(null))
          .catch((error: BusinessError) => result.error('pause_failed', error.message, null));
        break;

      case 'seekTo': {
        const positionMs = call.argument('positionMs') as number;
        kernel.seekTo(positionMs === undefined ? 0 : positionMs)
          .then(() => result.success(null))
          .catch((error: BusinessError) => result.error('seek_failed', error.message, null));
        break;
      }

      case 'setSpeed': {
        const speed = call.argument('speed') as number;
        kernel.setSpeed(speed === undefined ? 1.0 : speed)
          .then(() => result.success(null))
          .catch((error: BusinessError) => result.error('speed_failed', error.message, null));
        break;
      }

      case 'setVolume': {
        const volume = call.argument('volume') as number;
        kernel.setVolume(volume === undefined ? 1.0 : volume)
          .then(() => result.success(null))
          .catch((error: BusinessError) => result.error('volume_failed', error.message, null));
        break;
      }

      case 'dispose':
        kernel.release();
        result.success(null);
        break;

      default:
        result.notImplemented();
        break;
    }
  }
}
