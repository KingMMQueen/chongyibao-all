param(
    [string]$Source = "assets\branding\app_icon.png",
    # 传入 SVG 时，先用 Chrome 无头模式渲染成 1024 的 PNG，再生成各端图标
    [string]$Svg = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$srcPath = Join-Path $root $Source

if ($Svg -ne "") {
    $svgPath = Join-Path $root $Svg
    if (-not (Test-Path $svgPath)) {
        throw "找不到 SVG：$svgPath"
    }
    $chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
    if (-not (Test-Path $chrome)) {
        throw "找不到 Chrome，无法渲染 SVG：$chrome"
    }

    $svgUrl = "file:///" + ($svgPath -replace '\\', '/')
    $html = @"
<!doctype html>
<html><head><meta charset="utf-8"><style>
  html, body { margin:0; padding:0; background:#ffffff; width:1024px; height:1024px; overflow:hidden; }
  body { display:flex; align-items:center; justify-content:center; }
  img { width:860px; height:860px; display:block; }
</style></head>
<body><img src="$svgUrl"></body></html>
"@
    $htmlPath = Join-Path $env:TEMP "cyb-icon-render.html"
    [System.IO.File]::WriteAllText($htmlPath, $html, (New-Object System.Text.UTF8Encoding $false))

    Write-Host "渲染 SVG -> 1024 PNG" -ForegroundColor Cyan
    Remove-Item $srcPath -Force -ErrorAction SilentlyContinue
    # Chrome 会把 "bytes written to file" 写到 stderr，这里必须临时放宽错误策略，
    # 否则会被 $ErrorActionPreference = "Stop" 当成致命错误中断脚本。
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
        --default-background-color=FFFFFFFF --window-size=1024,1024 `
        --screenshot="$srcPath" ("file:///" + ($htmlPath -replace '\\', '/')) *> $null
    $ErrorActionPreference = $previousEap
    Start-Sleep -Seconds 2
}

if (-not (Test-Path $srcPath)) {
    throw "找不到源图：$srcPath"
}

$srcImage = [System.Drawing.Image]::FromFile($srcPath)
Write-Host "源图: $srcPath ($($srcImage.Width)x$($srcImage.Height))" -ForegroundColor Cyan
if ($srcImage.Width -lt 1024) {
    Write-Host "警告：源图小于 1024px，iOS 1024 图标将被放大，可能偏模糊。" -ForegroundColor Yellow
}
$srcImage.Dispose()

function New-Icon {
    param(
        [string]$Dst,
        [int]$Size,
        [switch]$Opaque
    )

    $image = [System.Drawing.Image]::FromFile($srcPath)

    # iOS 的 App Store 图标不允许带 Alpha 通道（即便像素全不透明也会被拒），
    # 必须用 24bpp RGB 画布，PNG 才会写成 colorType=2。
    if ($Opaque) {
        $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    } else {
        $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    }
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    # iOS 的 App Store 图标不允许带透明通道，必须铺不透明底色
    if ($Opaque) {
        $graphics.Clear([System.Drawing.Color]::White)
    } else {
        $graphics.Clear([System.Drawing.Color]::Transparent)
    }

    $graphics.DrawImage($image, 0, 0, $Size, $Size)
    $graphics.Dispose()

    $target = Join-Path $root $Dst
    $dir = Split-Path $target -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    $image.Dispose()
}

Write-Host "[1/3] Android mipmap" -ForegroundColor Cyan
$android = @(
    @{ Path = "android\app\src\main\res\mipmap-mdpi\ic_launcher.png"; Size = 48 },
    @{ Path = "android\app\src\main\res\mipmap-hdpi\ic_launcher.png"; Size = 72 },
    @{ Path = "android\app\src\main\res\mipmap-xhdpi\ic_launcher.png"; Size = 96 },
    @{ Path = "android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png"; Size = 144 },
    @{ Path = "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png"; Size = 192 }
)
foreach ($item in $android) {
    New-Icon -Dst $item.Path -Size $item.Size
    Write-Host "  $($item.Size)px -> $($item.Path)"
}

Write-Host "[2/3] iOS AppIcon（不透明）" -ForegroundColor Cyan
$ios = @(
    @{ Name = "Icon-App-20x20@1x.png"; Size = 20 },
    @{ Name = "Icon-App-20x20@2x.png"; Size = 40 },
    @{ Name = "Icon-App-20x20@3x.png"; Size = 60 },
    @{ Name = "Icon-App-29x29@1x.png"; Size = 29 },
    @{ Name = "Icon-App-29x29@2x.png"; Size = 58 },
    @{ Name = "Icon-App-29x29@3x.png"; Size = 87 },
    @{ Name = "Icon-App-40x40@1x.png"; Size = 40 },
    @{ Name = "Icon-App-40x40@2x.png"; Size = 80 },
    @{ Name = "Icon-App-40x40@3x.png"; Size = 120 },
    @{ Name = "Icon-App-60x60@2x.png"; Size = 120 },
    @{ Name = "Icon-App-60x60@3x.png"; Size = 180 },
    @{ Name = "Icon-App-76x76@1x.png"; Size = 76 },
    @{ Name = "Icon-App-76x76@2x.png"; Size = 152 },
    @{ Name = "Icon-App-83.5x83.5@2x.png"; Size = 167 },
    @{ Name = "Icon-App-1024x1024@1x.png"; Size = 1024 }
)
foreach ($item in $ios) {
    New-Icon -Dst ("ios\Runner\Assets.xcassets\AppIcon.appiconset\" + $item.Name) -Size $item.Size -Opaque
    Write-Host "  $($item.Size)px -> $($item.Name)"
}

Write-Host "[3/3] HarmonyOS" -ForegroundColor Cyan
New-Icon -Dst "ohos\AppScope\resources\base\media\app_icon.png" -Size 114
Write-Host "  114px -> ohos\AppScope\resources\base\media\app_icon.png"
New-Icon -Dst "ohos\entry\src\main\resources\base\media\icon.png" -Size 114
Write-Host "  114px -> ohos\entry\src\main\resources\base\media\icon.png"
New-Icon -Dst "ohos\entry\src\ohosTest\resources\base\media\icon.png" -Size 114
Write-Host "  114px -> ohos\entry\src\ohosTest\resources\base\media\icon.png"

Write-Host ""
Write-Host "图标生成完成（共 $($android.Count + $ios.Count + 3) 个文件）" -ForegroundColor Green
