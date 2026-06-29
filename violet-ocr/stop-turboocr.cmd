@echo off
setlocal
cd /d "%~dp0"

where docker >nul 2>nul
if errorlevel 1 (
  echo docker executable not found.
  exit /b 127
)

set "FOUND="
for /f "delims=" %%C in ('docker ps --format "{{.Names}}" ^| findstr /B /C:"violet-turboocr"') do (
  set "FOUND=1"
  echo Stopping %%C
  docker stop "%%C"
)

if not defined FOUND echo No running TurboOCR containers found.
