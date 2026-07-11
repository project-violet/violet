@echo off
setlocal EnableExtensions

set "INSTALL_DIR=%VIOLET_INSTALL_DIR%"
if not defined INSTALL_DIR set "INSTALL_DIR=%CD%\.violet"

set "COMPOSE_FILE=%VIOLET_COMPOSE_FILE%"
if not defined COMPOSE_FILE set "COMPOSE_FILE=%INSTALL_DIR%\docker-compose.yml"
set "COMPOSE_URL=%VIOLET_COMPOSE_URL%"
if not defined COMPOSE_URL set "COMPOSE_URL=https://raw.githubusercontent.com/project-violet/violet/main/docker-compose.release.yml"
set "DATA_ROOT=%VIOLET_DATA_ROOT%"
if not defined DATA_ROOT set "DATA_ROOT=%INSTALL_DIR%\data"

where docker >nul 2>nul
if errorlevel 1 (
    echo Docker is required but was not found in PATH.
    exit /b 1
)

docker compose version >nul 2>nul
if errorlevel 1 (
    echo Docker Compose v2 is required ^(docker compose^).
    exit /b 1
)

if not defined VIOLET_COMPOSE_FILE (
    where curl.exe >nul 2>nul
    if errorlevel 1 (
        echo curl.exe is required to download the release Compose file.
        exit /b 1
    )
    if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
    set "COMPOSE_TMP=%COMPOSE_FILE%.tmp"
    echo Downloading release Compose file from %COMPOSE_URL%...
    curl.exe -fsSL "%COMPOSE_URL%" -o "%COMPOSE_TMP%"
    if errorlevel 1 (
        echo Failed to download the release Compose file.
        if exist "%COMPOSE_TMP%" del /q "%COMPOSE_TMP%"
        exit /b 1
    )
    move /y "%COMPOSE_TMP%" "%COMPOSE_FILE%" >nul
    if errorlevel 1 (
        echo Failed to install the release Compose file.
        exit /b 1
    )
)

if not exist "%COMPOSE_FILE%" (
    echo Compose file not found: %COMPOSE_FILE%
    exit /b 1
)

set "MISSING=0"
for %%F in (data.db user.db merged-0.fscm graph.csv) do (
    if not exist "%DATA_ROOT%\%%F" (
        echo Missing data file: %DATA_ROOT%\%%F
        set "MISSING=1"
    )
)

if "%MISSING%"=="1" (
    echo Set VIOLET_DATA_ROOT to a folder containing the four data files.
    exit /b 1
)

set "VIOLET_DATA_ROOT=%DATA_ROOT%"
if not defined VIOLET_IMAGE_TAG set "VIOLET_IMAGE_TAG=latest"

echo Pulling Violet images ^(tag: %VIOLET_IMAGE_TAG%^)...
docker compose -f "%COMPOSE_FILE%" pull
if errorlevel 1 (
    exit /b 1
)

echo Starting Violet services with data from %VIOLET_DATA_ROOT%...
docker compose -f "%COMPOSE_FILE%" up -d --remove-orphans
if errorlevel 1 (
    exit /b 1
)

echo Violet services are running.
