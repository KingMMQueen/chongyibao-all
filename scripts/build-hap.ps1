param(
    [string]$FlutterSdk = "D:\flutter\flutter_ohos327",
    [string]$DevecoHome = "D:\deveco-kaifa",
    [ValidateSet("ohos-arm64", "ohos-x64")]
    [string]$TargetPlatform = "ohos-arm64",
    [ValidateSet("native", "simulated")]
    [string]$Kernel = "native",
    [switch]$Release
)

$ErrorActionPreference = "Stop"

# DevEco 26 使用「一体化内置 SDK」，版本元数据在 studio\sdk\default\sdk-pkg.json
# 外置下载的 sdk\<api>\ 目录缺少 sdk-pkg.json，hvigor 会报 00303312。
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
    Write-Host "目标架构: $TargetPlatform / 内核: $Kernel" -ForegroundColor Cyan
    & (Join-Path $FlutterSdk "bin\flutter.bat") build hap $mode "--target-platform=$TargetPlatform" "--dart-define=PLAYER_KERNEL=$Kernel"
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
