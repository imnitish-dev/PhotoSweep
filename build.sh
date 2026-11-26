#!/bin/sh
# Builds PhotoSweep.app into ./build (needs Xcode Command Line Tools: xcode-select --install)
set -e
cd "$(dirname "$0")"
A=build/PhotoSweep.app
mkdir -p "$A/Contents/MacOS"
cp Info.plist "$A/Contents/Info.plist"
swiftc -O -swift-version 5 -parse-as-library main.swift -o "$A/Contents/MacOS/PhotoSweep"
codesign -s "${SIGN_ID:--}" --force --options runtime "$A"   # SIGN_ID="Developer ID Application: ..." for a signed build
echo "Built $A — drag it to /Applications, or run: open $A"

# ./build.sh dmg  → also package build/PhotoSweep.dmg (drag-to-Applications installer)
if [ "$1" = dmg ]; then
  rm -rf build/dmg build/PhotoSweep.dmg
  mkdir build/dmg && cp -R "$A" build/dmg/ && ln -s /Applications build/dmg/Applications
  hdiutil create -volname PhotoSweep -srcfolder build/dmg -format UDZO -quiet build/PhotoSweep.dmg
  echo "Built build/PhotoSweep.dmg"
fi
