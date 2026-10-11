@echo off
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is not installed. Install Node.js 20+ from https://nodejs.org/
  pause
  exit /b 1
)
if not exist node_modules (
  echo Installing web dependencies for first run...
  call npm install
  if errorlevel 1 goto failed
)
call npm run dev
if errorlevel 1 goto failed
exit /b 0
:failed
echo Offscreen web app could not start. Copy the error above.
pause
