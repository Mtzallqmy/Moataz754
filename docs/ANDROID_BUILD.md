# Android build and release

The Android app is exported from `Masalik-3D/` with official Godot 4.7.2 stable and its matching Android templates. It uses the Compatibility renderer and the original package name `com.moataz.masalik`. The development milestone is version code 3, version `0.3.0-alpha`. Android 8.0/API 26 and ARM64 are declared by the verified APK.

## Local build

Install JDK 17 or a compatible JDK, Android SDK Build Tools 36.1.0, Python 3, ripgrep and the pinned Godot version. Install the matching official export templates. Configure the Android and Java SDK paths in Godot Editor Settings and set `ANDROID_HOME` or `ANDROID_SDK_ROOT` for the shell.

```bash
scripts/validate-my-car.sh
scripts/build-my-car-android.sh debug
```

The build script starts from Godot's stock prebuilt ARM64 template. Godot sets the package and target SDK. A bounded binary-manifest edit sets the minimum SDK from 24 to 26 before alignment and signing. The script checks the package, ABI, minimum SDK, absence of network permissions, signature and alignment, then writes the APK and checksum. It avoids a local Gradle dependency for the standard export.

The development APK uses a newly generated Android debug key and is for separate installs on test devices. Android accepts an update only with the original application's matching release signing identity and a suitable version code.

## GitHub Actions and production signing

The workflow at `.github/workflows/my-car-android.yml` validates the pinned engine and template checksums, runs native tests, builds a debug APK, and uploads the APK, checksum and test log. Approved tags matching `my-car-v*` add a production signing job and publish a GitHub Release only after successful verification.

Use repository secrets `MYCAR_KEYSTORE_B64`, `MYCAR_KEY_ALIAS`, `MYCAR_STORE_PASS` and `MYCAR_KEY_PASS` for the existing release keystore. Set the repository variable `MYCAR_EXPECTED_CERT_SHA256` to the trusted SHA-256 of the previous release certificate. The build rejects a mismatched certificate and never writes signing material to the repository.

A device acceptance run should cover a fresh installation in airplane mode, first launch, starting a mission, changing a vehicle, saving, closing and reopening. Test touchscreen layout and frame pacing on API 26 and representative modern devices before tagging a production release.
