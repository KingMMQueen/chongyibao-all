# AGENTS.md

本项目为「一套 Dart 代码运行 Android / iOS / HarmonyOS」的视频与图集应用。
所有代码由 AI 生成，因此本文件的约束具有强制力，任何生成结果与之冲突时以本文件为准。

## 1. 版本基线（硬约束）

- Flutter **3.27.4**（鸿蒙分支 `br_3.27.4-ohos-1.0.4`）/ Dart **3.6**
- 禁止使用 Flutter 3.28+ 才有的 API 或 Dart 3.7+ 才有的语法
- 新增依赖前必须确认其 `environment.sdk` 兼容 Dart 3.6，且不依赖 Flutter 3.28+

原因：鸿蒙端只能跑在 3.27.4-ohos 上，任何高版本特性都会导致鸿蒙端编译失败。
SDK 来源：`https://gitcode.com/openharmony-sig/flutter_flutter`（注意是 gitcode，
gitee 上的同名仓库已停止更新，其 `3.22.1-ohos` 分支实际是未打补丁的上游代码）。

## 2. 目录职责（硬约束）

| 目录 | 职责 | 允许依赖 |
|---|---|---|
| `lib/presentation/` | 页面与组件 | `domain/`、`platform/` 的公开接口 |
| `lib/domain/` | 实体与仓储契约 | 仅 `core/` |
| `lib/data/` | 数据源与仓储实现 | `domain/`、`core/` |
| `lib/platform/` | 平台能力（播放器、图片、上传） | `core/` |
| `lib/core/` | 配置、日志、错误、工具 | 无 |

`domain/` 不得依赖 Flutter 的 UI 包；`presentation/` 不得直接 `import 'dart:io'`。

## 3. 平台差异（硬约束）

1. **所有平台差异只能出现在 `lib/platform/` 内**。
   `presentation/` 中禁止出现 `Platform.isAndroid` / `Platform.operatingSystem` 之类的判断。
2. 平台能力必须通过抽象接口暴露，Dart 侧实现保持单一（参考
   `NativePlayerKernel`：三端共用一份 Dart 代码，只注册同名通道）。
3. **未实现的能力必须抛 `PlatformUnsupportedFailure`**，禁止：
   - 返回 `null` / 空列表 / 默认值
   - 静默 `catch` 后什么都不做
   - `try { } catch (_) { }`

## 4. 播放器（硬约束）

- 画面必须通过 `Texture(textureId: ...)` 输出，**禁止使用原生视图叠层**
  （Android `SurfaceView`、鸿蒙 `XComponent` 若直接叠在 Flutter 视图上，
  会导致圆角、遮挡、截图全部失效）。
- 播放器 UI 全部自绘（见 `widgets/player_controls.dart`），不得使用平台播放控件。
- 原生通道契约定义在 `lib/platform/media/player_channel.dart`，改动必须同步三端。
- 倍速必须「变速不变调」：Android 用 `PlaybackParameters(speed, 1f)`，
  iOS 设置 `audioTimePitchAlgorithm = .timeDomain`。
- **鸿蒙端必须按 AVPlayer 状态机实现**：给 `url` 赋值后，要等 `stateChange`
  进入 `initialized` 才设置 `surfaceId` 并 `prepare()`。在 `idle` 状态直接
  `prepare()` 会报 `Prepare operation only supports stopped/initialized`。
  画面通路：`TextureRegistry.getTextureId()` → `registerTexture()` →
  `getSurfaceId()` → 赋给 `AVPlayer.surfaceId`。
- 鸿蒙端 `prepare()/seek()` 在 ArkTS 类型声明里返回 `void`，**不能接 `.catch()`**，
  必须用 try/catch；`play/pause/setSpeed/setVolume` 才可以 await。
- 鸿蒙端事件回传统一用 `Map<string, Object>`（StandardMessageCodec 支持 Map，
  ArkTS 下不要用普通对象字面量）。

## 5. 业务约束

- 视频为**纯 MP4 点播**，无直播、无 DRM、无内购。
- MP4 由服务端保证 faststart（moov 前置）且支持 HTTP Range，
  才能拖动进度；客户端不做补救。
- 图片只加载服务端缩略图（URL 带宽度参数），不加载原图。
- 续播位置通过 `PlayerController` 的 `_positionMemory` 管理，
  换成持久化实现时接口不得变化。

## 6. 完成定义（Definition of Done）

任何改动在提交前必须通过：

```powershell
flutter analyze
flutter test
```

**不允许「看起来对」就交付。** 由于代码由 AI 生成、无人逐行评审，
自动化测试是唯一的正确性保障。新增业务逻辑必须补充对应测试。

## 7. 三端构建

```powershell
# Android（必须用脚本，原因见下节「已知环境缺陷」）
.\scripts\build-apk.ps1
.\scripts\build-apk.ps1 -Release

# iOS（无本地 Mac，走 Codemagic 云构建）
# 见 tool/ci/codemagic.yaml

# HarmonyOS（使用鸿蒙分支 SDK）
$env:PATH = "D:\flutter\flutter_ohos327\bin;" + $env:PATH
flutter build hap --release
```

鸿蒙端还需安装 DevEco Studio 与 HarmonyOS SDK，并配置 `HOS_SDK_HOME` / `DEVECO_SDK_HOME`。

## 7.1 已知环境缺陷（必须遵守的规避方式）

1. **只要项目里存在 `ohos/` 目录，该分支的任何 `flutter build` 都会强制校验鸿蒙 SDK**
   （`project.dart` → `hvigor.updateLocalProperties` → `exitWithNoSdkMessage`）。
   未安装 DevEco 时，Android 构建会被误报为 `No Hmos SDK found`。
   → 规避方式：用 `scripts/build-apk.ps1`，它会在构建期间临时移开 `ohos/`。
   安装鸿蒙 SDK 后此问题自动消失。

2. **Gradle 官方发行包在部分网络下握手失败**。
   `android/gradle/wrapper/gradle-wrapper.properties` 已改用腾讯云镜像，不要改回官方地址。

3. **Flutter 必须能找到 Android SDK**。
   已执行 `flutter config --android-sdk D:\android_tools\android_sdk\android-sdk-windows`；
   换机器后需要重新执行。

4. **Android 端必须用 `SurfaceProducer`，禁止用 `createSurfaceTexture()`**。
   Flutter 3.27 在 Android 上默认启用 Impeller(Vulkan)，旧的 SurfaceTexture 外部纹理
   会持续报 `Invalid external texture`，画面永远不刷新（真机已实测复现）。
   正确做法：`textureRegistry.createSurfaceProducer()`，把 `getSurface()` 交给
   `ExoPlayer.setVideoSurface()`，在 `onVideoSizeChanged` 里调用 `setSize(w, h)`。
   同时**不要**自行调用 `SurfaceTexture.setOnFrameAvailableListener`。

5. **DevEco 26 必须使用一体化内置 SDK**。
   `HOS_SDK_HOME` / `DEVECO_SDK_HOME` 指向 `D:\deveco-kaifa\studio\sdk`，
   不要指向 `D:\deveco-kaifa\sdk`（后者的 `<api>` 目录没有 `sdk-pkg.json`，
   hvigor 会报 `00303312 Cannot find the corresponding SDK version`）。

6. **`compatibleSdkVersion` 必须是纯版本号**。
   DevEco 26 下写 `"26.0.0"`；写成 `"5.0.0(12)"` 或 `"26.0.0(26)"` 都会报
   `00308018 api version parameter is illegal`。

7. **hap 必须签名才能安装**。命令行只能产出 `entry-default-unsigned.hap`。
   签名在 DevEco Studio 中配置一次即可：
   打开 `ohos/` 工程 → File → Project Structure → Signing Configs →
   勾选 Automatically generate signature（需登录华为账号）。
   生成的签名信息会写回 `ohos/build-profile.json5` 的 `signingConfigs`，
   之后 `scripts/build-hap.ps1` 可直接出可安装包。

## 8. iOS 专项（硬约束）

1. **iOS 播放内核在 `packages/media_kernel_ios/`**（本地 Flutter 插件包），
   不要往 `ios/Runner/` 里直接加 Swift 文件——那需要手改 `project.pbxproj`，
   无 Mac 环境极易改坏。插件走 CocoaPods 自动集成。
2. **构建 iOS 必须用官方 Flutter 3.27.4**，不要用鸿蒙分支 SDK。
   Android/HarmonyOS 用分支，iOS 用官方，Dart 版本都是 3.6，代码无需分叉。
3. **`ios/Runner/GeneratedPluginRegistrant.m` 可能在 Windows 上不更新**，
   由 macOS 上的 `flutter build ipa` 重新生成。若本地发现为空，
   按 Swift 插件的写法手工补 `[PlayerPlugin registerWithRegistrar:...]`。
4. **无本地 Mac，所有 iOS 改动必须经 Codemagic 验证后才能算完成**。
   禁止仅凭「代码看起来对」就认为 iOS 端可用。
5. 画面通路：`AVPlayerItemVideoOutput` 输出 `CVPixelBuffer`，
   由 `FlutterTexture.copyPixelBuffer()` 取走；用 `CADisplayLink` 轮询
   `hasNewPixelBuffer` 并调用 `textureFrameAvailable`。
6. 变速不变调：`AVPlayerItem.audioTimePitchAlgorithm = .timeDomain`。
7. podspec 的 `platform` 必须 ≤ 工程的 `IPHONEOS_DEPLOYMENT_TARGET`（当前 12.0），
   否则 `pod install` 报平台不兼容。

## 9. 禁止事项

- 禁止在 `pubspec.yaml` 引入带原生代码的第三方包，除非三端都有对应实现
- 禁止使用 `print`，统一用 `AppLog`
- 禁止把环境地址硬编码在业务层，统一放 `lib/core/config.dart`
- 禁止为了「先跑起来」而临时绕过平台层
