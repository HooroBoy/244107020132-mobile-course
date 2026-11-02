# Membuat ikon aplikasi Campus Notify (tidak default).
#
# Menghasilkan dua berkas PNG yang dipakai `flutter_launcher_icons`:
#   assets/icon/app_icon.png            -> ikon penuh (legacy + web)
#   assets/icon/app_icon_foreground.png -> lapisan depan adaptive icon (transparan)
#
# Jalankan dari root proyek:
#   powershell -ExecutionPolicy Bypass -File tools/make_app_icon.ps1
#   dart run flutter_launcher_icons
#
# Palet mengikuti seed color aplikasi (#0B6E4F) supaya ikon dan tema konsisten.

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'assets\icon'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$size = 1024
$greenDark = [System.Drawing.ColorTranslator]::FromHtml('#0B6E4F')
$greenLight = [System.Drawing.ColorTranslator]::FromHtml('#17A87E')
$amber = [System.Drawing.ColorTranslator]::FromHtml('#FFC857')
$white = [System.Drawing.Color]::White

function New-Canvas {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    return @($bmp, $g)
}

function New-RoundedPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

# Lonceng: bahu melengkung ke puncak, sisi turun, lalu bibir lonceng (lip) tebal.
function New-BellPath {
    $bell = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bell.StartFigure()
    # Bahu kiri -> puncak.
    $bell.AddBezier(362, 500, 362, 372, 424, 320, 512, 320)
    # Puncak -> bahu kanan.
    $bell.AddBezier(512, 320, 600, 320, 662, 372, 662, 500)
    # Sisi kanan turun ke bibir.
    $bell.AddBezier(662, 500, 676, 548, 690, 576, 700, 592)
    # Dasar (ditutup oleh bibir).
    $bell.AddLine(700, 592, 324, 592)
    # Sisi kiri naik kembali ke bahu.
    $bell.AddBezier(324, 592, 334, 576, 348, 548, 362, 500)
    $bell.CloseFigure()
    return $bell
}

function Draw-Bell($g, [System.Drawing.Brush]$brush) {
    $bell = New-BellPath
    $g.FillPath($brush, $bell)
    $bell.Dispose()

    # Bibir lonceng: batang tebal dengan ujung membulat.
    $lip = New-RoundedPath 288 588 448 60 30
    $g.FillPath($brush, $lip)
    $lip.Dispose()

    # Pemukul lonceng, menempel di bawah bibir.
    $g.FillEllipse($brush, 456, 668, 112, 112)
}

function Draw-UnreadDot($g) {
    # Halo putih agar titik tetap terbaca di atas gradasi.
    $halo = New-Object System.Drawing.SolidBrush($white)
    $g.FillEllipse($halo, 668, 208, 148, 148)
    $dot = New-Object System.Drawing.SolidBrush($amber)
    $g.FillEllipse($dot, 690, 230, 104, 104)
    $halo.Dispose()
    $dot.Dispose()
}

# ---------------------------------------------------------------- ikon penuh
$pair = New-Canvas
$bmp = $pair[0]
$g = $pair[1]

$bgRect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
$gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $bgRect, $greenDark, $greenLight, [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal)
$rounded = New-RoundedPath 0 0 $size $size 210
$g.FillPath($gradient, $rounded)

$whiteBrush = New-Object System.Drawing.SolidBrush($white)
Draw-Bell $g $whiteBrush
Draw-UnreadDot $g

$g.Dispose()
$gradient.Dispose()
$rounded.Dispose()
$whiteBrush.Dispose()
$fullPath = Join-Path $outDir 'app_icon.png'
$bmp.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# ------------------------------------------------- lapisan depan adaptive icon
# Latar transparan; isi diperkecil agar masuk zona aman (66%) adaptive icon.
$pair = New-Canvas
$bmp = $pair[0]
$g = $pair[1]

$g.TranslateTransform(512, 512)
$g.ScaleTransform(0.78, 0.78)
$g.TranslateTransform(-512, -512)

$whiteBrush = New-Object System.Drawing.SolidBrush($white)
Draw-Bell $g $whiteBrush
Draw-UnreadDot $g

$g.Dispose()
$whiteBrush.Dispose()
$fgPath = Join-Path $outDir 'app_icon_foreground.png'
$bmp.Save($fgPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Output "Ikon dibuat:"
Write-Output "  $fullPath"
Write-Output "  $fgPath"
