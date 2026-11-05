$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
# Cardline icon: flat mint disc, a white line across the top and two rounded cards hanging from it.
$bitmap = New-Object System.Drawing.Bitmap(64, 64)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)
$discBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 43, 182, 138))
$linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 3)
$linePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$linePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$cardBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$pegBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 227, 246, 238))
$windowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 43, 182, 138))
$graphics.FillEllipse($discBrush, 1, 1, 62, 62)
$graphics.DrawBezier($linePen, 9, 19, 24, 25, 40, 25, 55, 19)
function Add-RoundedRect([System.Drawing.Graphics]$g, [System.Drawing.Brush]$brush, [float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($x, $y, $r * 2, $r * 2, 180, 90)
    $path.AddArc($x + $w - $r * 2, $y, $r * 2, $r * 2, 270, 90)
    $path.AddArc($x + $w - $r * 2, $y + $h - $r * 2, $r * 2, $r * 2, 0, 90)
    $path.AddArc($x, $y + $h - $r * 2, $r * 2, $r * 2, 90, 90)
    $path.CloseFigure()
    $g.FillPath($brush, $path)
    $path.Dispose()
}
Add-RoundedRect $graphics $cardBrush 13 27 17 22 4
Add-RoundedRect $graphics $windowBrush 16 30 11 11 2
Add-RoundedRect $graphics $cardBrush 34 25 17 22 4
Add-RoundedRect $graphics $windowBrush 37 28 11 11 2
Add-RoundedRect $graphics $pegBrush 19 19 5 10 2.5
Add-RoundedRect $graphics $pegBrush 40 17 5 10 2.5
$iconHandle = $bitmap.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($iconHandle)
$iconFile = [System.IO.File]::Create((Join-Path $PSScriptRoot 'Cardline.ico'))
try { $icon.Save($iconFile) } finally { $iconFile.Dispose(); $graphics.Dispose(); $linePen.Dispose(); $discBrush.Dispose(); $cardBrush.Dispose(); $pegBrush.Dispose(); $windowBrush.Dispose(); $icon.Dispose(); $bitmap.Dispose() }
Write-Output 'Created Cardline icon.'
