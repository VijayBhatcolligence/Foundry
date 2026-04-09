#!/bin/bash
# Build iOS release with obfuscation and debug symbols
# Usage: ./scripts/build_ios_release.sh
# Run from: foundry-app/flutter/

set -e

echo "========================================"
echo "  Foundry iOS Release Build"
echo "========================================"
echo ""

# Verify we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: Run this script from the foundry-app/flutter/ directory"
  exit 1
fi

# Clean previous build artifacts
echo "[1/3] Cleaning previous build..."
flutter clean

# Get dependencies
echo "[2/3] Fetching dependencies..."
flutter pub get

# Build with obfuscation
echo "[3/3] Building IPA with obfuscation..."
flutter build ipa \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-info/ios \
  --tree-shake-icons

echo ""
echo "========================================"
echo "  Build Complete"
echo "========================================"
echo ""
echo "IPA location:       build/ios/ipa/"
echo "Debug symbols:      build/debug-info/ios/"
echo ""
echo "IMPORTANT: Keep build/debug-info/ios/ for crash report symbolication."
echo "           Do NOT commit debug symbols to git (already in .gitignore)."
echo ""
echo "Next steps:"
echo "  1. Open Xcode → Organizer to upload IPA to App Store Connect"
echo "  2. Or use: xcrun altool --upload-app ..."
echo "  3. Upload debug symbols to Firebase Crashlytics if configured"
