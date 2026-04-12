@echo off
REM Build script for Android APK
echo Building Trace Wallet Mobile for Android...

REM Check if Flutter is installed
flutter --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Flutter is not installed or not in PATH.
    echo Please install Flutter from: https://docs.flutter.dev/get-started/install
    pause
    exit /b 1
)

REM Get dependencies
echo Getting Flutter dependencies...
flutter pub get

REM Build release APK
echo Building release APK...
flutter build apk --release

if %ERRORLEVEL% == 0 (
    echo Build successful!
    echo APK location: build\app\outputs\flutter-apk\app-release.apk
    
    REM Also build app bundle for Play Store
    echo Building app bundle for Play Store...
    flutter build appbundle --release
    echo AAB location: build\app\outputs\bundle\release\app-release.aab
) else (
    echo Build failed. Check Flutter setup and dependencies.
)

pause
