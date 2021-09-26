// This source code is a part of Project Violet.
// Copyright (C) 2020-2021. violet-team. Licensed under the Apache-2.0 License.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/cert/cert_data.dart';
import 'package:violet/cert/cert_util.dart';
import 'package:violet/cert/root.dart';

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
  });

  /*
  for linux 

  git clone https://github.com/abner/quickjs-c-bridge
  cd quickjs-c-bridge
  cmake -S ./linux -B ./build/linux
  cmake --build build/linux
  sudo cp build/linux/libquickjs_c_bridge_plugin.so /usr/lib/libquickjs_c_bridge_plugin.so
  */
  test("JS Simple Test", () async {
    JavascriptRuntime flutterJs;
    flutterJs = getJavascriptRuntime();

    flutterJs.onMessage('fromFlutter', (dynamic args) {
      print(args);
    });

    flutterJs.evaluate('''
      console.log('asdf');
      sendMessage('fromFlutter',  JSON.stringify('tt'));
      function test(ar) {return ar + '3';}
    ''');

    expect(flutterJs.evaluate("test('mm')").rawResult, 'mm3');
  });
}
