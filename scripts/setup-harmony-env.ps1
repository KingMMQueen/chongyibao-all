param(
    [string]$StudioHome = "D:\deveco-kaifa\studio",
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

# DevEco 26 起使用一体化内置 SDK，元数据在 <sdk>\default\sdk-pkg.json。
# 外置下载的 sdk\<api>\ 目录没有该文件，hvigor 会报 00303312。
$SdkHome = Join-Path $StudioHome "sdk"

Write-Host "DevEco Studio: $StudioHome" -ForegroundColor Cyan
Write-Host "HarmonyOS SDK: $SdkHome" -ForegroundColor Cyan
Write-Host ""

$ok = $true

if (Test-Path $StudioHome) {
    Write-Host "[OK]   DevEco Studio 目录存在" -ForegroundColor Green
} else {
    Write-Host "[MISS] 未找到 DevEco Studio：$StudioHome" -ForegroundColor Red
    $ok = $false
}

# SDK 版本元数据
$pkgJsons = @()
if (Test-Path $SdkHome) {
    $pkgJsons = Get-ChildItem $SdkHome -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName "sdk-pkg.json") } |
        Select-Object -ExpandProperty Name
}

if ($pkgJsons.Count -gt 0) {
    Write-Host "[OK]   SDK 版本目录: $($pkgJsons -join ', ')" -ForegroundColor Green
} else {
    Write-Host "[MISS] $SdkHome 下没有含 sdk-pkg.json 的版本目录" -ForegroundColor Red
    $ok = $false
}

# hdc
$hdc = Get-ChildItem $SdkHome -Recurse -Filter "hdc.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -ne $hdc) {
    Write-Host "[OK]   hdc 位于 $($hdc.FullName)" -ForegroundColor Green
} else {
    Write-Host "[MISS] 未找到 hdc.exe" -ForegroundColor Red
    $ok = $false
}

# ohpm
$ohpm = Join-Path $StudioHome "tools\ohpm\bin\ohpm.bat"
if (Test-Path $ohpm) {
    Write-Host "[OK]   ohpm 位于 $ohpm" -ForegroundColor Green
} else {
    Write-Host "[MISS] 未找到 ohpm.bat" -ForegroundColor Red
    $ok = $false
}

# hvigorw
$hvigorw = Join-Path $StudioHome "tools\hvigor\bin\hvigorw.bat"
if (Test-Path $hvigorw) {
    Write-Host "[OK]   hvigorw 位于 $hvigorw" -ForegroundColor Green
} else {
    Write-Host "[MISS] 未找到 hvigorw.bat" -ForegroundColor Red
    $ok = $false
}

# node
if ($null -ne (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[OK]   node $(& node -v)" -ForegroundColor Green
} else {
    Write-Host "[MISS] PATH 中没有 node，hvigor 无法运行" -ForegroundColor Red
    $ok = $false
}

if (-not $ok) {
    Write-Host ""
    Write-Host "环境未就绪，跳过写入。" -ForegroundColor Yellow
    exit 1
}

if (-not $Apply) {
    Write-Host ""
    Write-Host "环境检查通过。加 -Apply 参数写入用户环境变量。" -ForegroundColor Cyan
    exit 0
}

[Environment]::SetEnvironmentVariable("HOS_SDK_HOME", $SdkHome, "User")
[Environment]::SetEnvironmentVariable("DEVECO_SDK_HOME", $SdkHome, "User")

$dirsToAdd = New-Object System.Collections.Generic.List[string]
if ($null -ne $hdc) {
    $dirsToAdd.Add((Split-Path $hdc.FullName -Parent))
}
$dirsToAdd.Add((Join-Path $StudioHome "tools\ohpm\bin"))
$dirsToAdd.Add((Join-Path $StudioHome "tools\hvigor\bin"))

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
foreach ($dir in $dirsToAdd) {
    if ($userPath -notlike "*$dir*") {
        $userPath = "$userPath;$dir"
        Write-Host "已加入 PATH: $dir" -ForegroundColor Green
    }
}
[Environment]::SetEnvironmentVariable("Path", $userPath, "User")

Write-Host ""
Write-Host "环境变量已写入（需重开终端）。验证命令：" -ForegroundColor Green
Write-Host "  flutter doctor -v"
Write-Host "  .\scripts\build-hap.ps1"
