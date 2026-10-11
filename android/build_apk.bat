@echo off
setlocal
cd /d "%~dp0"
echo ==========================================
echo Offscreen Android APK builder
echo ==========================================
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found. Install Flutter and add its bin folder to PATH.
  echo Guide: https://docs.flutter.dev/get-started/install/windows/mobile
  pause
  exit /b 1
)
echo [1/4] Creating Android project files if needed...
flutter create --platforms=android --org com.offscreen.app .
if errorlevel 1 goto fail
echo [2/4] Applying offline Android settings...
python tool\prepare_android.py
if errorlevel 1 goto fail
echo [3/4] Downloading Flutter packages...
flutter pub get
if errorlevel 1 goto fail
echo [4/4] Building release APK for ARM64 Android phones...
flutter build apk --release --target-platform android-arm64
if errorlevel 1 goto fail
echo.
echo SUCCESS! APK is at:
echo build\app\outputs\flutter-apk\app-release.apk
pause
exit /b 0
:fail
echo.
echo Build failed. Copy the full error text and send it to ChatGPT.
pause
exit /b 1
