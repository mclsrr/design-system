# Regenerate the raster sizes from the supplied master. Windows uses the supplied ICO directly.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore, WindowsBase
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$icon = Join-Path $Root 'assets\app-icon'
$source = [Windows.Media.Imaging.BitmapFrame]::Create([Uri]::new((Join-Path $icon 'launcher.png')))

function Resize-Icon([int] $size) {
  $scale = $size / $source.PixelWidth
  return [Windows.Media.Imaging.TransformedBitmap]::new($source, [Windows.Media.ScaleTransform]::new($scale, $scale))
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

function Save-Icns([string] $path) {
  $chunks = foreach ($e in @(@('ic07', 128), @('ic08', 256), @('ic09', 512), @('ic10', 1024))) { , @($e[0], (Png (Resize-Icon $e[1]))) }
  $total = 8; foreach ($c in $chunks) { $total += 8 + $c[1].Length }
  $bw = [IO.BinaryWriter]::new([IO.File]::Create($path))
  $be = { param([uint32] $v) $x = [BitConverter]::GetBytes($v); [Array]::Reverse($x); $bw.Write($x) }
  $bw.Write([Text.Encoding]::ASCII.GetBytes('icns')); & $be $total
  foreach ($c in $chunks) { $bw.Write([Text.Encoding]::ASCII.GetBytes($c[0])); & $be (8 + $c[1].Length); $bw.Write([byte[]]$c[1]) }
  $bw.Close()
}

foreach ($s in 16, 24, 32, 48, 64, 128, 256, 512) {
  Save-Png (Resize-Icon $s) (Join-Path $icon "hicolor\${s}x${s}\apps\ai.storyteller.artcraft-launcher.png")
}
Save-Png (Resize-Icon 1024) (Join-Path $icon 'artcraft-launcher-1024.png')
Save-Icns (Join-Path $icon 'artcraft-launcher.icns')
