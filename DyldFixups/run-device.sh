#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
DEVICE_ID="${DEVICE_ID:-00008120-000C70962662601E}"
TEAM="${DEVELOPMENT_TEAM:-JASSJ2R9D6}"
DERIVED_DATA="$ROOT/DerivedData"
RUNS="${RUNS:-5}"
SCHEMES=(Baseline RebaseDense RebaseSparse BindRepeated BindUnique)

cd "$ROOT"
./generate-project.sh
: > static-fixups.txt
: > run-output.txt

for scheme in $SCHEMES; do
  xcodebuild -project DyldFixupsLab.xcodeproj \
    -scheme "$scheme" \
    -configuration Release \
    -destination "platform=iOS,id=$DEVICE_ID" \
    -derivedDataPath "$DERIVED_DATA" \
    DEVELOPMENT_TEAM="$TEAM" \
    CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates \
    build > "$ROOT/build-output.txt" 2>&1

  app="$DERIVED_DATA/Build/Products/Release-iphoneos/$scheme.app"
  executable="$app/$scheme"
  print "===== $scheme: static summary =====" >> static-fixups.txt
  python3 analyze_macho.py "$scheme" "$executable" >> static-fixups.txt
  for framework in "$app"/Frameworks/*.framework(N); do
    image="$framework/${framework:t:r}"
    [[ -f "$image" ]] || continue
    python3 analyze_macho.py "$scheme" "$image" >> static-fixups.txt
  done

  xcrun devicectl device install app --device "$DEVICE_ID" "$app" > /dev/null
  for run in {1..$RUNS}; do
    print "===== $scheme run=$run =====" >> run-output.txt
    xcrun devicectl device process launch --device "$DEVICE_ID" \
      --terminate-existing --console "com.tommywu.lab.dyldfixups.${scheme:l}" \
      >> run-output.txt 2>&1 || true
  done

  xcrun devicectl device uninstall app --device "$DEVICE_ID" "com.tommywu.lab.dyldfixups.${scheme:l}" > /dev/null 2>&1 || true
done

cat static-fixups.txt
cat run-output.txt
