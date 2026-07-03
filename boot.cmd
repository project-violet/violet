@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "ROOT=%~dp0"
set "HSYNC_DIR=%ROOT%violet-web\packages\backend\data"
set "MESSAGE_SEARCH_DIR=%ROOT%violet-message-search"
set "GRAPH_DIR=%ROOT%violet-graph"
set "GRAPH_CSV=%GRAPH_DIR%\graph.csv"
set "WEB_DIR=%ROOT%violet-web"

echo [1/4] Running hsync-go bootstrap...
if not exist "%HSYNC_DIR%\hsync-go.exe" (
  echo ERROR: missing "%HSYNC_DIR%\hsync-go.exe"
  exit /b 1
)

pushd "%HSYNC_DIR%" || exit /b 1
hsync-go.exe
set "HSYNC_EXIT=%ERRORLEVEL%"
popd

if not "%HSYNC_EXIT%"=="0" (
  echo ERROR: hsync-go.exe failed with exit code %HSYNC_EXIT%
  exit /b %HSYNC_EXIT%
)

echo [2/4] Starting message search server...
if not exist "%MESSAGE_SEARCH_DIR%" (
  echo ERROR: missing "%MESSAGE_SEARCH_DIR%"
  exit /b 1
)
start "violet message search" /D "%MESSAGE_SEARCH_DIR%" cmd /k cargo run -r --bin fast-search-rs --features raw -- 127.0.0.1 12332 --data-paths data/merged-0.json data/merged-1.json data/merged-2.json

echo [3/4] Starting graph server...
if not exist "%GRAPH_DIR%\violet-graph.exe" (
  echo ERROR: missing "%GRAPH_DIR%\violet-graph.exe"
  exit /b 1
)
if not exist "%GRAPH_CSV%" (
  echo ERROR: missing "%GRAPH_CSV%"
  exit /b 1
)
start "violet keyword graph" /D "%GRAPH_DIR%" cmd /k .\violet-graph.exe serve --input "%GRAPH_CSV%" --port 8787

echo [4/4] Starting violet-web dev server...
if not exist "%WEB_DIR%\package.json" (
  echo ERROR: missing "%WEB_DIR%\package.json"
  exit /b 1
)
start "violet web" /D "%WEB_DIR%" cmd /k npm.cmd run dev

echo.
echo Boot complete.
echo - Message search: http://127.0.0.1:12332
echo - Keyword graph: http://127.0.0.1:8787
echo - Violet web: npm dev window

exit /b 0
