#!/bin/bash
# MiYouHide 构建脚本（必须在 macOS + Xcode 环境运行，GitHub Actions 的 macos-14 即可）
set -euo pipefail
cd "$(dirname "$0")"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
OUT="build"
rm -rf "$OUT"; mkdir -p "$OUT"

echo "== SDK: $SDK"
xcrun --sdk iphoneos clang \
  -arch arm64 \
  -miphoneos-version-min=14.0 \
  -fobjc-arc \
  -O2 \
  -isysroot "$SDK" \
  -dynamiclib \
  -framework Foundation \
  -framework UIKit \
  -install_name @executable_path/MiYouHide.dylib \
  -o "$OUT/MiYouHide.dylib" \
  src/WLHook.m src/WLUI.m \
  -undefined dynamic_lookup

echo "== built:"; ls -l "$OUT/MiYouHide.dylib"
file "$OUT/MiYouHide.dylib" || true

# 伪签名（TrollStore / TrollFools 需要）
if command -v ldid >/dev/null 2>&1; then
  echo "== sign with ldid"
  ldid -S"$OUT/MiYouHide.dylib"
else
  echo "== ldid 不存在，尝试 codesign ad-hoc"
  codesign -s - -f --timestamp=none "$OUT/MiYouHide.dylib"
fi

otool -L "$OUT/MiYouHide.dylib" || true
echo "== done"
