#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build -c release
harmonic_bin_dir="$(swift build -c release --show-bin-path)"
harmonic_app_dir="$PWD/dist/Harmonic Lab.app"
mkdir -p "$harmonic_app_dir/Contents/MacOS" "$harmonic_app_dir/Contents/Resources"
cp "$harmonic_bin_dir/HarmonicLab" "$harmonic_app_dir/Contents/MacOS/HarmonicLab"
cp packaging/Info.plist "$harmonic_app_dir/Contents/Info.plist"
if [[ -f packaging/AppIcon.icns ]]; then
  cp packaging/AppIcon.icns "$harmonic_app_dir/Contents/Resources/AppIcon.icns"
fi
codesign --force --sign - "$harmonic_app_dir"
echo "Built: $harmonic_app_dir"
