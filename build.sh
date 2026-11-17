#!/bin/bash
set -e

echo "🔨 Kompilieren von Spaces.pock..."
mkdir -p Spaces.pock/Contents/MacOS
cp src/Info.plist Spaces.pock/Contents/Info.plist

swiftc -emit-library src/SpacesWidget.swift \
  -module-name Spaces \
  -o Spaces.pock/Contents/MacOS/Spaces \
  -framework Cocoa \
  -F /System/Library/PrivateFrameworks -framework SkyLight

if [ "$1" == "--install" ]; then
  echo "📦 Installiere Widget in Pock / PockV3..."
  mkdir -p ~/Library/Application\ Support/com.pigigaldi.pock/Widgets
  mkdir -p ~/Library/Application\ Support/Pock/Widgets
  cp -R Spaces.pock ~/Library/Application\ Support/com.pigigaldi.pock/Widgets/
  cp -R Spaces.pock ~/Library/Application\ Support/Pock/Widgets/
  killall PockV3 2>/dev/null || true
  killall Pock 2>/dev/null || true
  open -a PockV3 2>/dev/null || open -a Pock 2>/dev/null || true
  echo "✅ Fertig! Öffne 'Customize Pock' in der Menüleiste."
else
  mkdir -p release
  zip -r -q release/Spaces.pock.zip Spaces.pock
  echo "✅ Build erfolgreich! Release-Archiv unter: release/Spaces.pock.zip"
fi
