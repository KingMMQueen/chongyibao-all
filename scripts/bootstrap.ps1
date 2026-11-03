param(
    [string]$SdkPath = "D:\flutter\flutter_ohos327"
)

$ErrorActionPreference = "Stop"
$flutter = Join-Path $SdkPath "bin\flutter.bat"

if (-not (Test-Path $flutter)) {
    Write-Host "未找到鸿蒙 Flutter SDK: $flutter" -ForegroundColor Red
    Write-Host ""
    Write-Host "请先安装（需能访问 gitcode.com）："
    Write-Host "  git clone -b br_3.27.4-ohos-1.0.4 --depth 1 ``"
    Write-Host "    https://gitcode.com/openharmony-sig/flutter_flutter.git $SdkPath"
    Write-Host "  cd $SdkPath; git tag 3.27.4"
    exit 1
}

$env:PATH = (Join-Path $SdkPath "bin") + ";" + $env:PATH
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    Write-Host "[1/3] 安装依赖..." -ForegroundColor Cyan
    & $flutter pub get

    Write-Host "[2/3] 生成宿主工程（缺失时）..." -ForegroundColor Cyan
    if (-not (Test-Path "android")) {
        & $flutter create --platforms=android,ios --org com.chongyibao --project-name chongyibao .
    }
    if (-not (Test-Path "ohos")) {
        & $flutter create --platforms=ohos --org com.chongyibao --project-name chongyibao .
    }

    Write-Host "[3/3] 静态检查与测试..." -ForegroundColor Cyan
    & $flutter analyze
    & $flutter test
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "完成。运行：" -ForegroundColor Green
Write-Host "  flutter run -d <device>"
Write-Host "  flutter run -d <device> --dart-define=PLAYER_KERNEL=native"
