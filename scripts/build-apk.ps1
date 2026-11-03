param(
    [string]$FlutterSdk = "D:\flutter\flutter_ohos327",
    [string]$AndroidSdk = "D:\android_tools\android_sdk\android-sdk-windows",
    [string]$DevecoHome = "D:\deveco-kaifa",
    [ValidateSet("native", "simulated")]
    [string]$Kernel = "native",
    [switch]$Release
)

$ErrorActionPreference = "Stop"

$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk

# 安装鸿蒙 SDK 后，构建 Android 不再因项目里存在 ohos/ 而被拦截，
# 但仍需把 SDK 相关路径补齐，供 flutter_tools 做工具链检查。
$harmonySdk = Join-Path $DevecoHome "studio\sdk"
$env:HOS_SDK_HOME = $harmonySdk
$env:DEVECO_SDK_HOME = $harmonySdk

$extraPath = @(
    (Join-Path $DevecoHome "studio\sdk\default\openharmony\toolchains"),
    (Join-Path $DevecoHome "studio\tools\ohpm\bin"),
    (Join-Path $DevecoHome "studio\tools\hvigor\bin"),
    (Join-Path $FlutterSdk "bin")
) -join ";"
$env:PATH = "$extraPath;$env:PATH"

$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $mode = if ($Release) { "--release" } else { "--debug" }
    Write-Host "播放内核: $Kernel" -ForegroundColor Cyan
    & (Join-Path $FlutterSdk "bin\flutter.bat") build apk $mode "--dart-define=PLAYER_KERNEL=$Kernel"
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
