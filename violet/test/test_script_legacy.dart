// This source code is a part of Project Violet.
// Copyright (C) 2020-2021. violet-team. Licensed under the Apache-2.0 License.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/cert/cert_data.dart';
import 'package:violet/cert/cert_util.dart';
import 'package:violet/cert/root.dart';
import 'package:violet/script/script_runner.dart';

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
  });

  test("Test Script Runner Simple", () async {
    var cache = ScriptCache("""if (or(gre(sum(x,y), sub(x,y)), iscon(x,y,z))) [
    foreach (k : arrayx) [
        print(k)]
    k[3] = 6 // Assign 6 to k[3]
] else if (not(iscon(x,y,z))) [
    k[2] = 7
]""");
    var runner = ScriptIsolate(cache);

    print(cache.printTree());
    // runner.runScript(null);
    expect(true, true);
  });
}
