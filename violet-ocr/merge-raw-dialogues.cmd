@echo off
setlocal
cd /d "%~dp0"

set "PYTHON_EXE="

if defined VIOLET_PYTHON (
  if exist "%VIOLET_PYTHON%" set "PYTHON_EXE=%VIOLET_PYTHON%"
)

if not defined PYTHON_EXE (
  if exist "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" (
    set "PYTHON_EXE=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
  )
)

if defined PYTHON_EXE (
  "%PYTHON_EXE%" adjust_raw_dialogues.py --input-dir raw --output-dir raw-merged-v2 --count 2147483647 %*
  exit /b %ERRORLEVEL%
)

where py >nul 2>nul
if not errorlevel 1 (
  py -3 adjust_raw_dialogues.py --input-dir raw --output-dir raw-merged-v2 --count 2147483647 %*
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  python adjust_raw_dialogues.py --input-dir raw --output-dir raw-merged-v2 --count 2147483647 %*
  exit /b %ERRORLEVEL%
)

echo Python executable not found. Set VIOLET_PYTHON to python.exe.
exit /b 127
