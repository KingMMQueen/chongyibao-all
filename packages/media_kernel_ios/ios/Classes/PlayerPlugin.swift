import AVFoundation
import Flutter
import UIKit

/// iOS 播放内核：AVPlayer + AVPlayerItemVideoOutput + FlutterTexture。
///
/// 与 Android / HarmonyOS 共用通道契约（见 lib/platform/media/player_channel.dart）：
/// - MethodChannel: app.chongyibao/player
/// - EventChannel : app.chongyibao/player/events
///
/// 画面通路：AVPlayerItemVideoOutput 输出 CVPixelBuffer，
/// 由 FlutterTexture.copyPixelBuffer 取走，引擎合成到 Flutter 图层。
public class PlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

  private let textures: FlutterTextureRegistry
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?

  private var player: AVPlayer?
  private var playerItem: AVPlayerItem?
  private var videoOutput: AVPlayerItemVideoOutput?
  private var texture: PlayerTexture?
  private var textureId: Int64 = -1
  private var displayLink: CADisplayLink?
  private var timeObserverToken: Any?
  private var statusObservation: NSKeyValueObservation?
  private var rateObservation: NSKeyValueObservation?
  private var endObserver: NSObjectProtocol?

  private var hasSource = false
  private var hasStarted = false
  private var completed = false
  private var errorMessage: String?
  private var videoWidth = 0
  private var videoHeight = 0
  private var speed: Float = 1.0
  private var volume: Float = 1.0

  init(textures: FlutterTextureRegistry, messenger: FlutterBinaryMessenger) {
    self.textures = textures
    self.methodChannel = FlutterMethodChannel(
      name: "app.chongyibao/player",
      binaryMessenger: messenger)
    self.eventChannel = FlutterEventChannel(
      name: "app.chongyibao/player/events",
      binaryMessenger: messenger)
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PlayerPlugin(
      textures: registrar.textures(),
      messenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: instance.methodChannel)
    instance.eventChannel.setStreamHandler(instance)
  }

  // MARK: - FlutterStreamHandler

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    emitState()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // MARK: - FlutterPlugin

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "create":
      result(createTextureAndPlayer())

    case "setSource":
      guard let args = call.arguments as? [String: Any],
            let url = args["url"] as? String, !url.isEmpty else {
        result(FlutterError(code: "bad_args", message: "url 为空", details: nil))
        return
      }
      let startMs = (args["startPositionMs"] as? NSNumber)?.int64Value ?? 0
      setSource(url: url, startMs: startMs, result: result)

    case "play":
      hasStarted = true
      completed = false
      player?.rate = speed
      emitState()
      result(nil)

    case "pause":
      player?.rate = 0
      emitState()
      result(nil)

    case "seekTo":
      let args = call.arguments as? [String: Any]
      let ms = (args?["positionMs"] as? NSNumber)?.int64Value ?? 0
      seek(toMs: ms)
      result(nil)

    case "setSpeed":
      let args = call.arguments as? [String: Any]
      let value = (args?["speed"] as? NSNumber)?.floatValue ?? 1.0
      speed = value
      // 播放中直接改 rate 即可生效；pitch 由 audioTimePitchAlgorithm 保证不变调
      if let p = player, p.rate > 0 {
        p.rate = value
      }
      emitState()
      result(nil)

    case "setVolume":
      let args = call.arguments as? [String: Any]
      let value = (args?["volume"] as? NSNumber)?.floatValue ?? 1.0
      volume = value
      player?.volume = value
      emitState()
      result(nil)

    case "dispose":
      releasePlayer()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - 播放器生命周期

  private func createTextureAndPlayer() -> Int64 {
    releasePlayer()

    let attributes: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
    ]
    let output = AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
    videoOutput = output

    let t = PlayerTexture(output: output)
    texture = t
    textureId = textures.register(t)
    startDisplayLink()

    errorMessage = nil
    NSLog("[PlayerPlugin] texture created id=\(textureId)")
    return textureId
  }

  private func setSource(url: String, startMs: Int64, result: @escaping FlutterResult) {
    guard let output = videoOutput else {
      result(FlutterError(code: "no_texture", message: "请先调用 create", details: nil))
      return
    }
    guard let assetUrl = URL(string: url) else {
      result(FlutterError(code: "bad_url", message: "url 非法", details: nil))
      return
    }

    let item = AVPlayerItem(url: assetUrl)
    item.add(output)
    playerItem = item

    let p = AVPlayer(playerItem: item)
    p.actionAtItemEnd = .pause
    p.volume = volume
    player = p

    hasSource = true
    hasStarted = false
    completed = false
    errorMessage = nil

    observe(item: item, player: p)

    if startMs > 0 {
      p.seek(to: CMTime(value: startMs, timescale: 1000),
             toleranceBefore: .zero,
             toleranceAfter: .zero)
    }

    NSLog("[PlayerPlugin] open source: \(url) startAt=\(startMs)")
    emitState()
    result(nil)
  }

  private func observe(item: AVPlayerItem, player: AVPlayer) {
    statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard let self = self else { return }
      if item.status == .failed {
        self.errorMessage = item.error?.localizedDescription ?? "播放失败"
        NSLog("[PlayerPlugin] item failed: \(self.errorMessage ?? "")")
      }
      if item.status == .readyToPlay {
        // 变速不变调
        item.audioTimePitchAlgorithm = .timeDomain
        let size = item.presentationSize
        if size.width > 0 && size.height > 0 {
          self.videoWidth = Int(size.width)
          self.videoHeight = Int(size.height)
        }
      }
      self.emitState()
    }

    rateObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
      self?.emitState()
    }

    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      self?.completed = true
      self?.emitState()
    }

    timeObserverToken = player.addPeriodicTimeObserver(
      forInterval: CMTime(seconds: 0.2, preferredTimescale: 600),
      queue: .main
    ) { [weak self] _ in
      self?.emitState()
    }
  }

  private func seek(toMs ms: Int64) {
    guard let p = player else { return }
    p.seek(to: CMTime(value: ms, timescale: 1000),
           toleranceBefore: .zero,
           toleranceAfter: .zero)
    emitState()
  }

  private func releasePlayer() {
    displayLink?.invalidate()
    displayLink = nil

    statusObservation?.invalidate()
    statusObservation = nil
    rateObservation?.invalidate()
    rateObservation = nil

    if let token = timeObserverToken, let p = player {
      p.removeTimeObserver(token)
    }
    timeObserverToken = nil

    if let observer = endObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    endObserver = nil

    player?.pause()
    player = nil
    playerItem = nil
    videoOutput = nil

    if textureId >= 0 {
      textures.unregisterTexture(textureId)
      textureId = -1
    }
    texture = nil

    hasSource = false
    hasStarted = false
    completed = false
  }

  // MARK: - 纹理刷新

  private func startDisplayLink() {
    displayLink?.invalidate()
    let link = CADisplayLink(target: self, selector: #selector(onDisplayLinkTick))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  @objc private func onDisplayLinkTick() {
    guard textureId >= 0, let output = videoOutput, let p = player else { return }
    if p.rate == 0 { return }
    let hostTime = CACurrentMediaTime()
    let itemTime = output.itemTime(forHostTime: hostTime)
    if output.hasNewPixelBuffer(forItemTime: itemTime) {
      textures.textureFrameAvailable(textureId)
    }
  }

  // MARK: - 状态上报

  private func currentPhase() -> String {
    if errorMessage != nil {
      return "error"
    }
    guard let p = player, let item = playerItem else {
      return "idle"
    }
    if !hasSource {
      return "idle"
    }
    if item.status == .unknown {
      return "loading"
    }
    if item.status == .failed {
      return "error"
    }
    if p.rate > 0 {
      return "playing"
    }
    if completed {
      return "completed"
    }
    return hasStarted ? "paused" : "ready"
  }

  private func durationMs() -> Int64 {
    guard let item = playerItem else { return 0 }
    let duration = item.duration
    if !duration.isNumeric {
      return 0
    }
    return Int64(CMTimeGetSeconds(duration) * 1000.0)
  }

  private func positionMs() -> Int64 {
    guard let p = player else { return 0 }
    let time = p.currentTime()
    if !time.isNumeric {
      return 0
    }
    return Int64(CMTimeGetSeconds(time) * 1000.0)
  }

  private func emitState() {
    guard let sink = eventSink else { return }
    var payload: [String: Any] = [
      "phase": currentPhase(),
      "positionMs": positionMs(),
      "durationMs": durationMs(),
      "bufferedMs": durationMs(),
      "speed": Double(speed),
      "volume": Double(volume),
      "videoWidth": videoWidth,
      "videoHeight": videoHeight,
    ]
    // 不要放 Optional：StandardMessageCodec 无法编码 Swift 的 Optional 包装。
    // 无错误时直接不写该键，Dart 侧读到的就是 null。
    if let message = errorMessage {
      payload["errorMessage"] = message
    }
    DispatchQueue.main.async {
      sink(payload)
    }
  }

  deinit {
    releasePlayer()
  }
}

/// Flutter 纹理实现：从 AVPlayerItemVideoOutput 取最新一帧。
final class PlayerTexture: NSObject, FlutterTexture {
  private let output: AVPlayerItemVideoOutput

  init(output: AVPlayerItemVideoOutput) {
    self.output = output
    super.init()
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
    if output.hasNewPixelBuffer(forItemTime: itemTime),
       let buffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
      return Unmanaged.passRetained(buffer)
    }
    return nil
  }
}
