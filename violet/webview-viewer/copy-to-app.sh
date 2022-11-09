#!/bin/bash
## This source code is a part of Project Violet.
## Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

## copy build webview to assets subdirectory

rm -rf build/test-article
rm -rf ../assets/webview
mkdir ../assets/webview

mv build/index1.html build/index.html

cp -r build ../assets/webview