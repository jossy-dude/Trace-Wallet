# Build Instructions

## Prerequisites

### For Windows Desktop Build:
- Python 3.10+ (3.14 has issues with pythonnet, use 3.10-3.12)
- Visual Studio Build Tools (for pythonnet)
  - Download: https://visualstudio.microsoft.com/visual-cpp-build-tools/
  - Install "Desktop development with C++" workload
- Git

### For Android Mobile Build:
- Flutter SDK 3.0+
- Android Studio
- Android SDK
- JDK 17

---

## Windows Desktop Build

### Method 1: Using Build Script (Recommended)

```bash
# Run the build script
build_windows.bat
```

### Method 2: Manual Build

```bash
cd vault_analytics

# Create virtual environment
python -m venv venv
venv\Scripts\activate

# Install dependencies (Python 3.10-3.12 recommended)
pip install pywebview fastapi uvicorn pyinstaller

# Build executable
pyinstaller --name=VaultAnalytics --onefile --windowed --add-data="index.html;." --add-data="vault;vault" main.py

# Output: dist/VaultAnalytics.exe
```

### Troubleshooting Windows Build

**Error: "Failed building wheel for pythonnet"**
- Install Visual Studio Build Tools with C++ workload
- Or downgrade to Python 3.10/3.11

---

## Android Mobile Build

### Method 1: Using Build Script

```bash
# Run the build script
build_android.bat
```

### Method 2: Manual Build

```bash
# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

# Build app bundle for Play Store
flutter build appbundle --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Mobile App Features for P2P Sync

The mobile app needs to implement:

1. **UDP Discovery** - Listen for desktop vault broadcasts on port 5333
2. **QR Scanner** - Scan desktop QR code for instant pairing
3. **SMS Reader** - Read bank SMS messages
4. **HTTP Client** - Send SMS to desktop vault via REST API

See `README.md` for Flutter integration code.

---

## GitHub Actions (Automated Builds)

The repository includes `.github/workflows/build.yml` for automated building on every push to main.

Outputs:
- Windows executable (artifacts)
- Android APK (artifacts)

---

## Version Info

Update version in these files before building:
- `pubspec.yaml` - version: x.x.x+x
- `vault_analytics/main.py` - Window title

## Release Checklist

1. Update version numbers
2. Run `build_windows.bat` 
3. Run `build_android.bat`
4. Test both builds
5. Create GitHub release with both artifacts
6. Update CHANGELOG.md
