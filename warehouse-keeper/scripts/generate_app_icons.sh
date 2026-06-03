#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/assets/brand/app_icon.svg"
ANDROID_RES="$ROOT_DIR/android/app/src/main/res"
IOS_ICONS="$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset"

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick 'magick' is required to generate app icons." >&2
  exit 1
fi

render_icon() {
  local size="$1"
  local output="$2"
  magick -background "#FFF4DC" "$SOURCE" -alpha remove -alpha off -resize "${size}x${size}" "$output"
}

render_icon 48 "$ANDROID_RES/mipmap-mdpi/ic_launcher.png"
render_icon 72 "$ANDROID_RES/mipmap-hdpi/ic_launcher.png"
render_icon 96 "$ANDROID_RES/mipmap-xhdpi/ic_launcher.png"
render_icon 144 "$ANDROID_RES/mipmap-xxhdpi/ic_launcher.png"
render_icon 192 "$ANDROID_RES/mipmap-xxxhdpi/ic_launcher.png"

render_icon 20 "$IOS_ICONS/Icon-App-20x20@1x.png"
render_icon 40 "$IOS_ICONS/Icon-App-20x20@2x.png"
render_icon 60 "$IOS_ICONS/Icon-App-20x20@3x.png"
render_icon 29 "$IOS_ICONS/Icon-App-29x29@1x.png"
render_icon 58 "$IOS_ICONS/Icon-App-29x29@2x.png"
render_icon 87 "$IOS_ICONS/Icon-App-29x29@3x.png"
render_icon 40 "$IOS_ICONS/Icon-App-40x40@1x.png"
render_icon 80 "$IOS_ICONS/Icon-App-40x40@2x.png"
render_icon 120 "$IOS_ICONS/Icon-App-40x40@3x.png"
render_icon 120 "$IOS_ICONS/Icon-App-60x60@2x.png"
render_icon 180 "$IOS_ICONS/Icon-App-60x60@3x.png"
render_icon 76 "$IOS_ICONS/Icon-App-76x76@1x.png"
render_icon 152 "$IOS_ICONS/Icon-App-76x76@2x.png"
render_icon 167 "$IOS_ICONS/Icon-App-83.5x83.5@2x.png"
render_icon 1024 "$IOS_ICONS/Icon-App-1024x1024@1x.png"

echo "Generated app icons from $SOURCE"
