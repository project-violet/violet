:: This source code is a part of Project Violet.
:: Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

:: copy build webview to assets subdirectory

rmdir build/test-article /S /Q
rmdir ..\assets\webview /S /Q
mkdir ..\assets\webview
powershell ./replace.ps1
move build\index1.html build\index.html
xcopy build ..\assets\webview /E