// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/script/script_runner.dart';

class ScriptHitomiGetImageList {
  static const String code = """
gg = download(concat("https://ltn.hitomi.la/galleries/", \$id, ".js"))
\$result = gg
  """;

  static Future<Map<String, dynamic>> run(int id) async {
    var sr = ScriptRunner(code);
    await sr.runScript({'\$id': RunVariable.fromInt(id)});
    return sr.getValue('\$result').toMap();
  }
}
