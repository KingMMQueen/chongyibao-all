param(
    [string]$Apk = "build\app\outputs\flutter-apk\app-debug.apk",
    [string]$Package = "com.qkx.xiaochong.cyb",
    [int]$LogSeconds = 12,
    [switch]$Native
)

$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    if (-not (Test-Path $Apk)) {
        Write-Host "未找到 APK：$Apk，请先运行 .\scripts\build-apk.ps1" -ForegroundColor Red
        exit 1
    }

    $devices = (& adb devices) | Select-Object -Skip 1 | Where-Object { $_ -match "\sdevice$" }
    if (-not $devices) {
        Write-Host "没有已授权的设备。请在手机上确认 USB 调试弹窗。" -ForegroundColor Red
        & adb devices -l
        exit 1
    }
    $serial = ($devices[0] -split "\s+")[0]
    Write-Host "目标设备: $serial" -ForegroundColor Cyan

    Write-Host "[1/3] 安装..." -ForegroundColor Cyan
    & adb -s $serial install -r $Apk | Write-Host

    Write-Host "[2/3] 启动..." -ForegroundColor Cyan
    & adb -s $serial shell am force-stop $Package | Out-Null
    & adb -s $serial logcat -c
    & adb -s $serial shell am start -n "$Package/$Package.MainActivity" | Write-Host

    Write-Host "[3/3] 采集 $LogSeconds 秒日志（播放器相关）..." -ForegroundColor Cyan
    Start-Sleep -Seconds $LogSeconds
    & adb -s $serial logcat -d -v brief |
        Select-String -Pattern "flutter|ExoPlayer|MediaCodec|AndroidRuntime|chongyibao|cyb" |
        Select-Object -Last 40

    if ($Native) {
        Write-Host ""
        Write-Host "提示：本包由 build-apk.ps1 构建，内核由 --dart-define 决定。" -ForegroundColor Yellow
        Write-Host "要验证真实播放，请用：flutter run --dart-define=PLAYER_KERNEL=native" -ForegroundColor Yellow
    }
}
finally {
    Pop-Location
}
