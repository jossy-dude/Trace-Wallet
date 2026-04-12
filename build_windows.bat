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

REM Install dependencies (matches CI and requirements.txt)
echo Installing dependencies...
pip install -r requirements.txt pyinstaller

REM Build executable with PyInstaller (single spec: datas, hidden imports)
echo Building executable...
pyinstaller VaultAnalytics.spec

if %ERRORLEVEL% == 0 (
    echo Build successful!
    echo Executable location: dist\VaultAnalytics.exe
) else (
    echo Build failed. Make sure you have Visual Studio Build Tools installed for pythonnet.
    echo Download from: https://visualstudio.microsoft.com/visual-cpp-build-tools/
)

pause
