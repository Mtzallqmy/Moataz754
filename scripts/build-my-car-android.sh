#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-debug}"
output="${2:-$repo/build/android/MyCar-ARM64.apk}"
sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
tools="${ANDROID_BUILD_TOOLS:-$sdk/build-tools/36.1.0}"
godot="${GODOT_BIN:-godot}"

case "$mode" in
  debug)
    temporary="$(mktemp -d)"
    export MYCAR_KEYSTORE="$temporary/debug.keystore"
    export MYCAR_KEY_ALIAS=androiddebugkey MYCAR_STORE_PASS=android MYCAR_KEY_PASS=android
    keytool -genkeypair -keystore "$MYCAR_KEYSTORE" -storepass android -alias androiddebugkey \
      -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=Android Debug,O=Android,C=US'
    ;;
  release)
    : "${MYCAR_KEYSTORE:?Original release signing keystore required}"
    : "${MYCAR_KEY_ALIAS:?Release key alias required}"
    : "${MYCAR_STORE_PASS:?Release store password required}"
    : "${MYCAR_KEY_PASS:?Release key password required}"
    : "${MYCAR_EXPECTED_CERT_SHA256:?Original signing certificate fingerprint required}"
    temporary="$(mktemp -d)"
    ;;
  *) printf 'Usage: %s [debug|release] [output.apk]\n' "$0" >&2; exit 2 ;;
esac
trap 'rm -rf -- "$temporary"' EXIT

for utility in aapt zipalign apksigner; do
  test -x "$tools/$utility"
done
mkdir -p -- "$(dirname -- "$output")"
output="$(realpath -m -- "$output")"

"$godot" --headless --path "$repo/Masalik-3D" "--export-$mode" 'Android ARM64' "$temporary/native.apk"
test -s "$temporary/native.apk"
python3 "$repo/scripts/android_manifest_min_sdk.py" "$temporary/native.apk" "$temporary/api26.apk"
"$tools/zipalign" -P 16 -f 4 "$temporary/api26.apk" "$temporary/aligned.apk"
"$tools/apksigner" sign --ks "$MYCAR_KEYSTORE" --ks-key-alias "$MYCAR_KEY_ALIAS" \
  --ks-pass env:MYCAR_STORE_PASS --key-pass env:MYCAR_KEY_PASS \
  --out "$temporary/signed.apk" "$temporary/aligned.apk"

apk="$temporary/signed.apk"
"$tools/zipalign" -c -P 16 4 "$apk"
"$tools/apksigner" verify --verbose --print-certs "$apk" | tee "$temporary/certificate.txt"
"$tools/aapt" dump badging "$apk" > "$temporary/badging.txt"
grep -Eq "^package: name='com\.moataz\.masalik'" "$temporary/badging.txt"
grep -Eq "^sdkVersion:'26'$" "$temporary/badging.txt"
grep -Eq "^native-code: 'arm64-v8a'$" "$temporary/badging.txt"
if grep -Eq "uses-permission.*android\.permission\.(INTERNET|ACCESS_NETWORK_STATE)" "$temporary/badging.txt"; then
  printf 'Unexpected network permission in APK.\n' >&2
  exit 1
fi
if [[ "$mode" == release ]]; then
  expected="$(tr -d ':' <<< "$MYCAR_EXPECTED_CERT_SHA256" | tr '[:upper:]' '[:lower:]')"
  actual="$(awk '/Signer #1 certificate SHA-256 digest:/ {print $NF}' "$temporary/certificate.txt")"
  [[ "$expected" =~ ^[0-9a-f]{64}$ && "$actual" == "$expected" ]]
  if grep -Eq '^application-debuggable' "$temporary/badging.txt"; then
    printf 'Release APK is debuggable.\n' >&2
    exit 1
  fi
fi
cp -- "$apk" "$output"
(cd -- "$(dirname -- "$output")" && sha256sum -- "$(basename -- "$output")" > "$(basename -- "$output").sha256")
grep -E "^package:|^sdkVersion:|^targetSdkVersion:|^native-code:|^uses-permission:" "$temporary/badging.txt"
ls -lh -- "$output"
cat -- "$output.sha256"
