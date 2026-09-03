#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h}"
DEVICE_ID="${DEVICE_ID:-BA9E1266-393F-4D92-8479-9C6D23D821D4}"
SCHEME="CopyLab"
BUNDLE_ID="com.tommywu.lab.CopyLab"
DERIVED_DATA="$PROJECT_DIR/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/CopyLab.app"

cd "$PROJECT_DIR"
xcodegen generate > /dev/null

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b

xcodebuild -project CopyLab.xcodeproj \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build > "$PROJECT_DIR/build-output.txt" 2>&1

xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl launch --console --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
  > "$PROJECT_DIR/run-output.txt" 2>&1

cat "$PROJECT_DIR/run-output.txt"
