#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
DEVICE_ID="${DEVICE_ID:-00008120-000C70962662601E}"
TEAM="${DEVELOPMENT_TEAM:-JASSJ2R9D6}"
DERIVED_DATA="$ROOT/DerivedData"
RUNS="${RUNS:-5}"
SCHEMES=(Baseline RebaseDense RebaseSparse BindRepeated BindUnique InitHeavy)

epoch_ms() { python3 -c 'import time; print(time.time_ns() // 1_000_000)'; }

cd "$ROOT"
./generate-project.sh
runtime_spec="$ROOT/.runtime-project.yml"
trap 'rm -f "$runtime_spec"; ./generate-project.sh >/dev/null' EXIT
: > static-fixups.txt
: > run-output.txt
: > phase-output.txt

for scheme in $SCHEMES; do
  runtime_bundle_id="com.tommywu.lab.dyldfixups.${scheme:l}"
  case "$scheme" in
    BindUnique)
      if [[ -n "${BUNDLE_ID_OVERRIDE_BINDUNIQUE:-}" ]]; then
        runtime_bundle_id="$BUNDLE_ID_OVERRIDE_BINDUNIQUE"
        cp project.yml "$runtime_spec"
        python3 - "$runtime_spec" "$runtime_bundle_id" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
app_id = sys.argv[2]
payload_id = app_id + ".payload"
text = path.read_text()
text = text.replace("PRODUCT_BUNDLE_IDENTIFIER: com.tommywu.lab.dyldfixups.bindunique\n        GCC_PREPROCESSOR_DEFINITIONS", f"PRODUCT_BUNDLE_IDENTIFIER: {app_id}\n        GCC_PREPROCESSOR_DEFINITIONS")
text = text.replace("PRODUCT_BUNDLE_IDENTIFIER: com.tommywu.lab.dyldfixups.bindunique.payload", f"PRODUCT_BUNDLE_IDENTIFIER: {payload_id}")
path.write_text(text)
PY
        xcodegen generate --spec "$runtime_spec" --project "$ROOT" --project-root "$ROOT" --quiet
      fi
      ;;
    InitHeavy)
      runtime_bundle_id="${BUNDLE_ID_OVERRIDE_INITHEAVY:-$runtime_bundle_id}"
      ;;
  esac

  build_cmd=(xcodebuild -project DyldFixupsLab.xcodeproj -scheme "$scheme" -configuration Release -destination "platform=iOS,id=$DEVICE_ID" -derivedDataPath "$DERIVED_DATA" DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates)
  if [[ "$scheme" == InitHeavy && -n "${BUNDLE_ID_OVERRIDE_INITHEAVY:-}" ]]; then
    build_cmd+=(PRODUCT_BUNDLE_IDENTIFIER="$runtime_bundle_id")
  fi
  build_start=$(epoch_ms)
  "${build_cmd[@]}" build > "$ROOT/build-output.txt" 2>&1
  build_end=$(epoch_ms)
  print "DYLDLAB_PHASE variant=$scheme phase=build bundle_id=$runtime_bundle_id wall_ms=$((build_end - build_start))" >> phase-output.txt

  app="$DERIVED_DATA/Build/Products/Release-iphoneos/$scheme.app"
  executable="$app/$scheme"
  print "===== $scheme: static summary =====" >> static-fixups.txt
  python3 analyze_macho.py "$scheme" "$executable" >> static-fixups.txt
  for framework in "$app"/Frameworks/*.framework(N); do
    image="$framework/${framework:t:r}"
    [[ -f "$image" ]] || continue
    python3 analyze_macho.py "$scheme" "$image" >> static-fixups.txt
  done

  install_start=$(epoch_ms)
  profile="$app/embedded.mobileprovision"
  xcrun devicectl device profile install --device "$DEVICE_ID" "$profile" --replace-existing > /dev/null
  xcrun devicectl device install app --device "$DEVICE_ID" "$app" > /dev/null
  install_end=$(epoch_ms)
  print "DYLDLAB_PHASE variant=$scheme phase=install bundle_id=$runtime_bundle_id wall_ms=$((install_end - install_start))" >> phase-output.txt

  for run in {1..$RUNS}; do
    print "===== $scheme run=$run =====" >> run-output.txt
    launch_start=$(epoch_ms)
    xcrun devicectl device process launch --device "$DEVICE_ID" \
      --terminate-existing --console "$runtime_bundle_id" \
      >> run-output.txt 2>&1 || true
    launch_end=$(epoch_ms)
    print "DYLDLAB_PHASE variant=$scheme phase=launch run=$run bundle_id=$runtime_bundle_id host_ms=$((launch_end - launch_start))" >> phase-output.txt
  done

  xcrun devicectl device uninstall app --device "$DEVICE_ID" "$runtime_bundle_id" > /dev/null 2>&1 || true
done

cat static-fixups.txt
cat phase-output.txt
cat run-output.txt
