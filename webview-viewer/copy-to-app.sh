#!/bin/bash
## This source code is a part of Project Violet.
## Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

## copy build webview to assets subdirectory

rm -rf ../assets/webview
mkdir ../assets/webview

cp -r build/* ../assets/webview