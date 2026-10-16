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
