#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/.build/app"
APP_DIR="$ROOT/dist/Estudio Cámara.app"
CONTENTS="$APP_DIR/Contents"

cd "$ROOT"
echo "Compilando Estudio Cámara…"
DEVELOPER_DIR="$(xcode-select -p)"
TOOLCHAIN="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin"
export SDKROOT="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
"$TOOLCHAIN/swift-build" -c release

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$BUILD_DIR"
cp "$ROOT/.build/release/EstudioCamara" "$CONTENTS/MacOS/EstudioCamara"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$CONTENTS/PkgInfo"
chmod +x "$CONTENTS/MacOS/EstudioCamara"

echo "App creada en: $APP_DIR"
