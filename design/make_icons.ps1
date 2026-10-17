# karen004.jpg からアプリのアイコン一式を作る。
# 使い方: .\design\make_icons.ps1 -Source design\karen004.jpg -OutDir web
# 切り抜き位置の初期値は、ペンとノートが入る範囲（2026-10 に選んだもの）。
param(
  [string]$Source = "$PSScriptRoot\karen004.jpg",
  [string]$OutDir = "$PSScriptRoot\..\web",
  [int]$CropX = 495, [int]$CropY = 0, [int]$CropSize = 560,
  [int]$MaskX = 455, [int]$MaskY = 0, [int]$MaskSize = 640
)
Add-Type -AssemblyName System.Drawing

function Save-Crop([System.Drawing.Image]$img, [int]$x, [int]$y, [int]$size, [int]$out, [string]$path) {
  $bmp = New-Object System.Drawing.Bitmap $out, $out
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $src = New-Object System.Drawing.Rectangle $x, $y, $size, $size
  $dst = New-Object System.Drawing.Rectangle 0, 0, $out, $out
  $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

$img = [System.Drawing.Image]::FromFile($Source)
try {
  Save-Crop $img $CropX $CropY $CropSize 32  "$OutDir\favicon.png"
  Save-Crop $img $CropX $CropY $CropSize 180 "$OutDir\icons\apple-touch-icon.png"
  Save-Crop $img $CropX $CropY $CropSize 192 "$OutDir\icons\Icon-192.png"
  Save-Crop $img $CropX $CropY $CropSize 512 "$OutDir\icons\Icon-512.png"
  # maskable は端が丸や円に切られるので、少し引いた範囲で作る
  Save-Crop $img $MaskX $MaskY $MaskSize 192 "$OutDir\icons\Icon-maskable-192.png"
  Save-Crop $img $MaskX $MaskY $MaskSize 512 "$OutDir\icons\Icon-maskable-512.png"
} finally {
  $img.Dispose()
}

# ---- iPhone アプリ版のアイコン（ios/Runner/Assets.xcassets/AppIcon.appiconset）----
# App Store は透明度（アルファ）付きのアイコンを受け付けないので、24 ビット RGB で保存する。
function Save-CropRgb([System.Drawing.Image]$img, [int]$x, [int]$y, [int]$size, [int]$out, [string]$path) {
  $bmp = New-Object System.Drawing.Bitmap $out, $out, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $src = New-Object System.Drawing.Rectangle $x, $y, $size, $size
  $dst = New-Object System.Drawing.Rectangle 0, 0, $out, $out
  $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

$iosDir = "$PSScriptRoot\..\ios\Runner\Assets.xcassets\AppIcon.appiconset"
if (Test-Path $iosDir) {
  $iosSizes = @{
    'Icon-App-20x20@1x.png' = 20;  'Icon-App-20x20@2x.png' = 40;  'Icon-App-20x20@3x.png' = 60
    'Icon-App-29x29@1x.png' = 29;  'Icon-App-29x29@2x.png' = 58;  'Icon-App-29x29@3x.png' = 87
    'Icon-App-40x40@1x.png' = 40;  'Icon-App-40x40@2x.png' = 80;  'Icon-App-40x40@3x.png' = 120
    'Icon-App-60x60@2x.png' = 120; 'Icon-App-60x60@3x.png' = 180
    'Icon-App-76x76@1x.png' = 76;  'Icon-App-76x76@2x.png' = 152
    'Icon-App-83.5x83.5@2x.png' = 167; 'Icon-App-1024x1024@1x.png' = 1024
  }
  $img = [System.Drawing.Image]::FromFile($Source)
  try {
    foreach ($name in $iosSizes.Keys) {
      Save-CropRgb $img $CropX $CropY $CropSize $iosSizes[$name] "$iosDir\$name"
    }
  } finally {
    $img.Dispose()
  }
}
