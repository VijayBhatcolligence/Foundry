#!/bin/bash
# Build Android release with obfuscation and debug symbols
# Usage: ./scripts/build_android_release.sh
# Run from: foundry-app/flutter/

set -e

echo "========================================"
echo "  Foundry Android Release Build"
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
echo "[3/3] Building App Bundle with obfuscation..."
flutter build appbundle \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-info/android \
  --tree-shake-icons

echo ""
echo "========================================"
echo "  Build Complete"
echo "========================================"
echo ""
echo "AAB location:       build/app/outputs/bundle/release/"
echo "Debug symbols:      build/debug-info/android/"
echo ""
echo "IMPORTANT: Keep build/debug-info/android/ for crash report symbolication."
echo "           Do NOT commit debug symbols to git (already in .gitignore)."
echo ""
echo "Next steps:"
echo "  1. Upload AAB to Google Play Console → Production / Internal Testing"
echo "  2. Upload debug symbols to Play Console → Android vitals → Deobfuscation files"
