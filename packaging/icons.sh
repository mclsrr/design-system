#!/usr/bin/env bash
# Regenerate launcher raster assets with ImageMagick 7. Keep the supplied Windows ICO verbatim.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
dir=assets/app-icon
id=ai.storyteller.artcraft-launcher
for size in 16 24 32 48 64 128 256 512; do
  magick "$dir/launcher.png" -resize "${size}x${size}" "$dir/hicolor/${size}x${size}/apps/$id.png"
done
magick "$dir/launcher.png" -resize 1024x1024 "$dir/artcraft-launcher-1024.png"
sizes=()
for size in 128 256 512; do
  sizes+=("$dir/hicolor/${size}x${size}/apps/$id.png")
done
cargo run -q -p xtask -- icns "$dir/artcraft-launcher.icns" "${sizes[@]}" "$dir/artcraft-launcher-1024.png"
