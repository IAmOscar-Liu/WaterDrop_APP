# Flutter AD Ecommerce

## Documentation

API contracts, backend handoffs, and implementation plans are organized in [doc/](doc/README.md).

## Environments

This project currently supports `dev` and `stg` flavors.

| Environment | App ID                                     | API base URL                         | Deeplink host                    |
| ----------- | ------------------------------------------ | ------------------------------------ | -------------------------------- |
| `dev`       | `com.waterdropapp.adecommerce.development` | `https://dev-api.waterdropping.com/` | `deeplink-dev.waterdropping.com` |
| `stg`       | `com.waterdropapp.adecommerce.stg`         | `https://stg-api.waterdropping.com/` | `deeplink-stg.waterdropping.com` |

Firebase files are environment-scoped:

```text
android/app/src/dev/google-services.json
android/app/src/stg/google-services.json
ios/Runner/Firebase/dev/GoogleService-Info.plist
ios/Runner/Firebase/stg/GoogleService-Info.plist
lib/firebase_options_dev.dart
lib/firebase_options_stg.dart
```

These Firebase files are ignored by Git. Regenerate them with FlutterFire CLI or copy them from your private credential storage before building.

## Setup

This project uses FVM.

```sh
fvm flutter pub get
```

## Run

Run dev:

```sh
fvm flutter run --flavor dev -t lib/main_dev.dart
```

Run staging:

```sh
fvm flutter run --flavor stg -t lib/main_stg.dart
```

Run dev against a local/ngrok API server:

```sh
fvm flutter run --flavor dev -t lib/main_dev.dart \
  --dart-define=API_BASE_URL=https://your-ngrok-url.ngrok-free.app/
```

You can replace the `API_BASE_URL` value with any reachable local tunnel URL. Keep the trailing `/`.

`API_BASE_URL` is only honored in non-release builds. Release builds, including Xcode archives for TestFlight, always use the flavor's configured API URL.

### Chatroom SSE rollout

The user-scoped SSE implementation uses the [confirmed backend sync contract](doc/FLUTTER_CHATROOM_SSE_API_CHANGES.md) and is enabled by default in all builds. No SSE flag is needed, including when using a local API tunnel:

```sh
fvm flutter run --flavor dev -t lib/main_dev.dart \
  --dart-define=API_BASE_URL=https://dorothea-overslavish-proficiently.ngrok-free.dev/
```

Pass `--dart-define=CHAT_SSE_ENABLED=false` to `flutter run` or `flutter build` to use the legacy polling path. The two paths do not run together.

The VS Code launch configurations use the same default. Fully stop and relaunch an existing debug session when changing compile-time defines; hot reload/restart does not change them.

When enabled, one foreground session connection updates all accessible rooms, previews, and unread counts. History uses 20-message pages with scroll-to-load older messages; sending/list/history/read operations use `/api/chatroom/sync/*`. Background/logout closes SSE and FCM remains responsible for notifications. Reconnect resumes the user-feed cursor; a reset reloads the list and mounted conversations. Failed sends retain their content and retry UUID in memory for the signed-in session, including across room navigation, but not across app termination/logout.

Local synchronization checks:

```sh
fvm flutter test test/chat
```

These mocked transport/controller/widget checks do not establish backend deployment, proxy flushing, or mobile background delivery. Verify those against the migrated staging environment before releasing.

### Message Center SSE

Message Center uses the [confirmed notification contract](doc/FLUTTER_NOTIFICATION_SSE_API_CHANGES.md). It is enabled by default, like chat, so the development command above also enables notification synchronization. Use `--dart-define=NOTIFICATION_SSE_ENABLED=false` to select the legacy notification REST behavior independently of chat. For environments awaiting the notification migration/deployment, use that override until the sync endpoints are ready.

After login, one foreground notification stream updates unread badges throughout the app. It has a separate cursor from chat; background/logout closes both connections, and resume replays each feed independently. Notifications use 20-item frozen pages, canonical read/delete responses, and versioned live updates. Text searches refresh through the server to preserve PostgreSQL search semantics; while browsing older results, use **更新搜尋結果** to apply a pending search refresh. FCM retains responsibility for alerts, including while Message Center is open, and does not independently increment the badges. Push-only chat/admin alerts do not create Message Center items.

Tapping a `command: message` push with `notificationId` opens the saved notification directly after login/account initialization, including cold launches. The detail is fetched from the API and marked read when displayed. Pushes without an ID open Message Center; inaccessible or deleted items return there with a notice. Receiving a push alone never navigates or marks an item read.

Run `fvm flutter test test/notification test/chat test/provider/chat_auth_refresh_test.dart` for controller, lifecycle, transport, and UI checks. Live backend/proxy and real-device FCM verification remain separate from these mocked checks. Restart the app after changing compile-time feature flags.

## Build

Build Android dev debug:

```sh
fvm flutter build apk --flavor dev -t lib/main_dev.dart --debug
```

Build Android staging debug:

```sh
fvm flutter build apk --flavor stg -t lib/main_stg.dart --debug
```

Build Android dev release APK:

```sh
fvm flutter build apk --flavor dev -t lib/main_dev.dart --release
```

Build Android staging release APK:

```sh
fvm flutter build apk --flavor stg -t lib/main_stg.dart --release
```

Build Android dev app bundle for Google Play:

```sh
fvm flutter build appbundle --flavor dev -t lib/main_dev.dart --release
```

Build Android staging app bundle for Google Play:

```sh
fvm flutter build appbundle --flavor stg -t lib/main_stg.dart --release
```

Release outputs:

```text
build/app/outputs/flutter-apk/app-dev-release.apk
build/app/outputs/flutter-apk/app-stg-release.apk
build/app/outputs/bundle/devRelease/app-dev-release.aab
build/app/outputs/bundle/stgRelease/app-stg-release.aab
```

For Google Play, upload the `.aab` file for the matching package name:

- Dev: `com.waterdropapp.adecommerce.development`
- Staging: `com.waterdropapp.adecommerce.stg`

Build iOS staging without code signing:

```sh
fvm flutter build ios --flavor stg -t lib/main_stg.dart --no-codesign
```

## Launcher Icons

Production launcher icons are configured in `pubspec.yaml` and currently use:

```text
assets/icons/playstore.png
assets/icons/appstore.png
```

Dev and staging icons are configured separately:

```text
flutter_launcher_icons-dev.yaml
flutter_launcher_icons-stg.yaml
assets/icons/playstore-dev.png
assets/icons/playstore-stg.png
assets/icons/appstore-dev.png
assets/icons/appstore-stg.png
```

Regenerate all configured flavor icons:

```sh
fvm dart run flutter_launcher_icons
```

Generated Android flavor icons live under:

```text
android/app/src/dev/res/
android/app/src/stg/res/
```

Generated iOS flavor icons live under:

```text
ios/Runner/Assets.xcassets/AppIcon-dev.appiconset
ios/Runner/Assets.xcassets/AppIcon-stg.appiconset
```

The iOS `Runner` target uses:

| Build configurations                      | App icon set  |
| ----------------------------------------- | ------------- |
| `Debug-dev`, `Release-dev`, `Profile-dev` | `AppIcon-dev` |
| `Debug-stg`, `Release-stg`, `Profile-stg` | `AppIcon-stg` |
| Unflavored configs                        | `AppIcon`     |

## Xcode Archive and TestFlight

To upload a flavored iOS build to TestFlight, archive the matching release configuration.

Recommended Xcode flow:

1. Open `ios/Runner.xcworkspace`
2. Select the `dev` or `stg` scheme in the top toolbar
3. Select `Any iOS Device`
4. Use `Product > Archive`
5. Upload from Xcode Organizer

The schemes are configured like this:

| Scheme | Archive build configuration | Bundle ID                                  | Firebase plist                                     |
| ------ | --------------------------- | ------------------------------------------ | -------------------------------------------------- |
| `dev`  | `Release-dev`               | `com.waterdropapp.adecommerce.development` | `ios/Runner/Firebase/dev/GoogleService-Info.plist` |
| `stg`  | `Release-stg`               | `com.waterdropapp.adecommerce.stg`         | `ios/Runner/Firebase/stg/GoogleService-Info.plist` |

If you are editing the generic `Runner` scheme manually, open `Edit Scheme > Archive` and choose the matching build configuration:

- Dev TestFlight build: `Release-dev`
- Staging TestFlight build: `Release-stg`

If a TestFlight build ever appears to use a local/ngrok URL, check `ios/Flutter/Generated.xcconfig` for a stale `DART_DEFINES` value from a previous local run. The app code ignores `API_BASE_URL` in release mode, but regenerating Flutter's iOS files before archiving is still a good reset:

```sh
fvm flutter build ios --flavor dev -t lib/main_dev.dart --release --no-codesign
```

## Add Production Firebase Later

When adding production, keep production files in `prod`-specific paths. The unflavored names should be reserved for actual production concepts, but this project currently keeps every Firebase file explicitly environment-scoped.

Expected production paths:

```text
android/app/src/prod/google-services.json
ios/Runner/Firebase/prod/GoogleService-Info.plist
lib/firebase_options_prod.dart
```

Use FlutterFire CLI like this:

```sh
flutterfire configure \
  --project=<production-firebase-project-id> \
  --platforms=android,ios \
  --android-package-name=com.waterdropapp.adecommerce \
  --ios-bundle-id=com.waterdropapp.adecommerce \
  --android-out=android/app/src/prod/google-services.json \
  --ios-out=ios/Runner/Firebase/prod/GoogleService-Info.plist \
  --out=lib/firebase_options_prod.dart \
  --overwrite-firebase-options
```

For example, if `traveladvisor-323109` were the production Firebase project:

```sh
flutterfire configure \
  --project=traveladvisor-323109 \
  --platforms=android,ios \
  --android-package-name=com.waterdropapp.adecommerce \
  --ios-bundle-id=com.waterdropapp.adecommerce \
  --android-out=android/app/src/prod/google-services.json \
  --ios-out=ios/Runner/Firebase/prod/GoogleService-Info.plist \
  --out=lib/firebase_options_prod.dart \
  --overwrite-firebase-options
```

After generating the files, also add the production flavor wiring:

- Add `prod` to `android/app/build.gradle.kts`
- Add iOS `prod` scheme/build configurations
- Add `prod` to `AppFlavor` in `lib/app_flavor.dart`
- Add `lib/main_prod.dart`
- Add the production API base URL in `lib/constants/app_constants.dart`
- Add a VS Code launch config for production if needed

## VS Code

Use the Run and Debug panel and select one of:

- `Flutter Dev`
- `Flutter Stg`
- `Flutter Dev Local API`

`Flutter Dev Local API` uses `API_BASE_URL` to point the app at the ngrok/local server.
