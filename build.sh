#!/bin/sh
# Builds PhotoSweep.app into ./build (needs Xcode Command Line Tools: xcode-select --install)
set -e
cd "$(dirname "$0")"
A=build/PhotoSweep.app
mkdir -p "$A/Contents/MacOS"
cp Info.plist "$A/Contents/Info.plist"
swiftc -O -swift-version 5 -parse-as-library main.swift -o "$A/Contents/MacOS/PhotoSweep"
codesign -s "${SIGN_ID:--}" --force "$A"   # SIGN_ID="Developer ID Application: ..." for a signed build
echo "Built $A — drag it to /Applications, or run: open $A"
