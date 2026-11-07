# Flezen Free

An initial Flutter reconstruction of the Flezen-style Android interface: dark theme, lavender accent, link entry, bookmarks, downloads, history, and direct media playback.

## Build an APK with GitHub Actions

1. Upload the contents of this ZIP to the root of your GitHub repository (`celo10862-cyber/Flezen-Free`).
2. Commit the files to the `main` branch.
3. Open the repository's **Actions** tab.
4. Select **Build Flezen Free APK** and choose **Run workflow**, or push a change to `lib/`.
5. When the run completes, open it and download the `flezen-free-release-apk` artifact.

The workflow creates the Android platform folder, installs Flutter dependencies, analyzes the source, builds a release APK, and uploads the APK as an artifact.

## Build locally on Windows

Install Flutter and Android Studio, then open PowerShell in this folder:

```powershell
flutter create --platforms=android --project-name flezen_free --org com.flezenfree .
flutter pub get
flutter build apk --release
```

APK output: `build\\app\\outputs\\flutter-apk\\app-release.apk`

## Current scope and limitations

- Plays direct HTTP/HTTPS media URLs whose paths end in common media extensions such as MP4, WebM, M3U8, MP3, and AAC, subject to device and server codec/stream support.
- Webpage links are offered for opening in the browser; this starter does not extract media from arbitrary websites.
- Downloads are saved inside the app's private storage in this starter build.
- Bookmarks, downloads, and history are currently in-memory and reset when the app process is cleared. Persistent storage and a proper downloads manager are planned improvements.
- Flezen share links may require the original service's API or server-side processing. This project does not claim compatibility with those links until that integration is available.
- This is a clean-room starter project, not recovered original Flezen source code. It does not bypass DRM, authentication, or third-party access controls.

## Project layout

```text
lib/main.dart
pubspec.yaml
analysis_options.yaml
.github/workflows/android.yml
```

# Flezen-Free automatic resolver patch

Extract this ZIP into the root of the existing repository, merge folders, then run from PowerShell in the repo root:

```powershell
python .\scripts\apply_resolver_patch.py
flutter pub get
flutter analyze
```

Review the diff before committing. The patch keeps the current Home, Saved, Downloads, History and shell. It adds Dio/HTML parsing plus a headless WebView fallback and changes the player to play the resolved URL, not the original webpage URL. HLS/DASH depend on Android ExoPlayer and server compatibility.

## Persistent signing setup

Create a single keystore on Windows and keep a secure offline backup:

```powershell
keytool -genkeypair -v -keystore flezen-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias flezenfree
$env:KEYSTORE_B64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\flezen-release.jks"))
Set-Clipboard $env:KEYSTORE_B64
```

In GitHub repository Settings → Secrets and variables → Actions, create:
- `ANDROID_KEYSTORE_BASE64` = clipboard content
- `ANDROID_KEYSTORE_PASSWORD` = keystore password
- `ANDROID_KEY_ALIAS` = `flezenfree` (or your chosen alias)
- `ANDROID_KEY_PASSWORD` = key password

Never commit the keystore or passwords. The included workflow deliberately fails if these secrets are missing; it does not create a throwaway key. Keep the same keystore for every future update.

## Limitations

This is a best-effort generic resolver, not universal extraction. It can inspect exposed HTML metadata, source/video/audio tags, common player config values and browser resource URLs. It cannot bypass DRM, passwords, authentication, signed server-side restrictions or private APIs. Some hosts need site-specific adapters, cookies, or token refresh logic. The example Flezen URL still needs a real-device test; this environment could not reach flezen.com to inspect its response.

The current app's Saved/History/Downloads lists remain in-memory. This patch does not yet persist them. Downloads target app-private storage and only work when the resolved source allows an ordinary HTTP download.

