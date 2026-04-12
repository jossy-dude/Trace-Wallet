@echo off
REM Build script for Windows executable
echo Building Vault Analytics for Windows...

cd vault_analytics

REM Check if virtual environment exists, create if not
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate

REM Install dependencies
echo Installing dependencies...
pip install pywebview fastapi uvicorn

REM Build executable with PyInstaller
echo Building executable...
pyinstaller --name=VaultAnalytics ^
    --onefile ^
    --windowed ^
    --add-data="index.html;." ^
    --add-data="vault;vault" ^
    --clean ^
    --noconfirm ^
    main.py

if %ERRORLEVEL% == 0 (
    echo Build successful!
    echo Executable location: dist\VaultAnalytics.exe
) else (
    echo Build failed. Make sure you have Visual Studio Build Tools installed for pythonnet.
    echo Download from: https://visualstudio.microsoft.com/visual-cpp-build-tools/
)

pause
