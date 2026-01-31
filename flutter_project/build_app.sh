#!/bin/bash
set -x
echo "DEBUG: Script execution started"

# Define project root relative to this script
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "🚀 Starting Flag Master Build Process..."

# 1. Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter command not found! Please ensure Flutter is installed and in your PATH."
    echo "   See: https://docs.flutter.dev/get-started/install"
    exit 1
fi

echo "✅ Flutter found."

# 2. Initialize Platform Files (Essential for new checkouts)
echo "📦 Ensuring platform files exist..."
# Repairs/creates android/ios directories if missing
flutter create . --org com.antigravity

# CHECK: Verify android/ directory exists now
if [ ! -d "android" ]; then
    echo "❌ 'flutter create' failed to generate the 'android' directory."
    echo "   Please check the output above for errors."
    exit 1
fi

# 3. Configure Release Signing (Android)
# Helper script is now in scripts/
SIGNING_SCRIPT="scripts/configure_android_signing.py"
if [ -f "$SIGNING_SCRIPT" ]; then
    echo "🔑 Configuring Android Release Signing..."
    if command -v python3 &> /dev/null; then
        python3 "$SIGNING_SCRIPT"
    else
        echo "⚠️  Python3 not found! Skipping automatic signing configuration."
    fi
else
    echo "ℹ️  Signing configuration script not found at $SIGNING_SCRIPT, skipping."
fi

# 4. Get Dependencies
echo "⬇️  Fetching dependencies..."
flutter pub get

# 5. Generate Icons (if package exists)
if grep -q "flutter_launcher_icons" pubspec.yaml; then
    echo "🎨 Generating App Icons..."
    dart run flutter_launcher_icons
fi

# 6. Build APK
echo "🏗️  Building APK for side-loading (Release Mode)..."
# Using --no-tree-shake-icons to avoid potential issues with icon font subsets if any
flutter build apk --release

echo "🎉 Build Complete!"
echo "📱 APK Location: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "To install on a connected device, run: flutter install"
