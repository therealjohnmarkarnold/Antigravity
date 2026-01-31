# Flag Master - Project Structure

This project has been consolidated and organized for reliable building.

## Directory Structure

- **root/**:
  - `lib/`: Contains all Dart source code.
    - `main.dart`: App entry point.
    - `flag_matching_game.dart`: Main game logic (Shape Matching).
    - `country_service.dart`: API service for fetching country data.
  - `assets/`: Contains static assets (App Icon).
  - `scripts/`: Contains helper scripts.
    - `configure_android_signing.py`: Configures keystore signing for release builds.
    - `download_flags.py`: (Legacy) Script to download flag assets.
  - `build_app.sh`: **Main build script**. Run this to build the APK.
  - `pubspec.yaml`: Project dependencies.

## How to Build

1.  **Run the Build Script**:
    ```bash
    ./build_app.sh
    ```
    This script will:
    -   Verify Flutter installation.
    -   Generate Android/iOS platform files (`flutter create`).
    -   Fetch dependencies (`flutter pub get`).
    -   Configure signing keys (Android).
    -   Generate App Icons.
    -   Build the Release APK.

2.  **Output**:
    The APK will be located at: `build/app/outputs/flutter-apk/app-release.apk`

## Troubleshooting

-   **Flutter Command Not Found**: Ensure you have the Flutter SDK installed and added to your `PATH`.
-   **Android Directory Missing**: The build script attempts to fix this by running `flutter create .`. If it fails, check the console output for errors.
