@echo off
setlocal
cd /d "%~dp0"

echo =====================================
echo Offscreen - first-time setup / launch
echo =====================================
echo.

if not exist ".venv\Scripts\python.exe" (
    echo Creating a Python virtual environment...
    py -3 -m venv .venv
    if errorlevel 1 (
        echo.
        echo ERROR: Python 3 was not found.
        echo Install Python from https://www.python.org/downloads/windows/
        echo During setup, tick "Add python.exe to PATH" if that option appears.
        pause
        exit /b 1
    )
)

echo Installing/checking the small app dependencies. This may need internet the first time.
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 (
    echo.
    echo ERROR: Could not install dependencies. Check your internet connection and try again.
    pause
    exit /b 1
)

echo.
echo Opening Offscreen in your browser...
".venv\Scripts\python.exe" -m streamlit run app.py
if errorlevel 1 (
    echo.
    echo The app stopped with an error. Copy the red error text and ask for help.
    pause
)
endlocal
