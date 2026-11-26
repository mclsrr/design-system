<#
.SYNOPSIS
  Renders every Design System icon (app icon PNG/ICO/ICNS, tray icons, the mark) from its shapes.

.DESCRIPTION
  The mark is a 2x2 grid of blocks (docs/brand/design-system-mark.svg); the app icon puts it on a
  dark rounded tile (assets/app-icon/artcraft-launcher.svg). Both are drawn here with WPF, so no
  extra tool is needed on Windows:
    powershell -ExecutionPolicy Bypass -File packaging\brand\generate.ps1
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore, WindowsBase
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Brush([string] $hex) { [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString($hex)) }

# Draws the 64-unit design scaled to $size px. $tile: dark background tile; $mono: one colour.
function Render([int] $size, [bool] $tile, [string] $mono = '') {
  $v = [Windows.Media.DrawingVisual]::new()
  $dc = $v.RenderOpen()
  $s = $size / 64.0
  $a = if ($mono) { Brush $mono } else { Brush '#2d6cf6' }
  $b = if ($mono) { Brush $mono } else { Brush '#6f97ff' }
  if ($tile) {
    $dc.DrawRoundedRectangle((Brush '#121316'), $null, [Windows.Rect]::new(0, 0, $size, $size), 14 * $s, 14 * $s)
    $o = 12; $w = 18; $g = 22
  } else {
    $o = 6; $w = 24; $g = 28
  }
  foreach ($cell in @(@(0, 0, $a, 0.25), @(1, 0, $b, 0.5), @(0, 1, $b, 0.5), @(1, 1, $a, 0.25))) {
    $x = ($o + $cell[0] * $g) * $s; $y = ($o + $cell[1] * $g) * $s; $r = $w * $cell[3] * $s
    $dc.DrawRoundedRectangle($cell[2], $null, [Windows.Rect]::new($x, $y, $w * $s, $w * $s), $r, $r)
  }
  $dc.Close()
  $bmp = [Windows.Media.Imaging.RenderTargetBitmap]::new($size, $size, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
  $bmp.Render($v)
  return $bmp
}

function Png($img) {
  $e = [Windows.Media.Imaging.PngBitmapEncoder]::new()
  $e.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($img))
  $ms = [IO.MemoryStream]::new(); $e.Save($ms); return , $ms.ToArray()
}

function Save-Png($img, [string] $path) {
  New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  [IO.File]::WriteAllBytes($path, (Png $img))
}

function Save-Ico([string] $path, [int[]] $sizes) {
  $pngs = foreach ($s in $sizes) { , (Png (Render $s $true)) }
  $bw = [IO.BinaryWriter]::new([IO.File]::Create($path))
  $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
  $off = 6 + 16 * $sizes.Count
  for ($i = 0; $i -lt $sizes.Count; $i++) {
    $d = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
    $bw.Write([byte]$d); $bw.Write([byte]$d); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$pngs[$i].Length); $bw.Write([uint32]$off)
    $off += $pngs[$i].Length
  }
  foreach ($p in $pngs) { $bw.Write([byte[]]$p) }
  $bw.Close()
}

function Save-Icns([string] $path) {
  $chunks = foreach ($e in @(@('ic07', 128), @('ic08', 256), @('ic09', 512), @('ic10', 1024))) { , @($e[0], (Png (Render $e[1] $true))) }
  $total = 8; foreach ($c in $chunks) { $total += 8 + $c[1].Length }
  $bw = [IO.BinaryWriter]::new([IO.File]::Create($path))
  $be = { param([uint32] $v) $x = [BitConverter]::GetBytes($v); [Array]::Reverse($x); $bw.Write($x) }
  $bw.Write([Text.Encoding]::ASCII.GetBytes('icns')); & $be $total
  foreach ($c in $chunks) { $bw.Write([Text.Encoding]::ASCII.GetBytes($c[0])); & $be (8 + $c[1].Length); $bw.Write([byte[]]$c[1]) }
  $bw.Close()
}

$icon = Join-Path $Root 'assets\app-icon'
foreach ($s in 16, 24, 32, 48, 64, 128, 256, 512) {
  Save-Png (Render $s $true) (Join-Path $icon "hicolor\${s}x${s}\apps\ai.storyteller.artcraft-launcher.png")
}
Save-Png (Render 1024 $true) (Join-Path $icon 'artcraft-launcher-1024.png')
Save-Ico (Join-Path $icon 'artcraft-launcher.ico') @(16, 24, 32, 48, 64, 128, 256)
Save-Icns (Join-Path $icon 'artcraft-launcher.icns')
$brand = Join-Path $Root 'docs\brand'
Save-Png (Render 64 $false) (Join-Path $brand 'design-system-mark-64.png')
Save-Png (Render 256 $false) (Join-Path $brand 'design-system-mark.png')
Save-Png (Render 44 $false '#000000') (Join-Path $brand 'design-system-mark-black-44.png')
Write-Host 'Design System icons rendered.'
