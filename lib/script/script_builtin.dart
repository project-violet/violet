// This source code is a part of Project Violet.
// Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/script/script_runner.dart';

typedef FunctionCallback = Future Function(List<RunVariable>);

class ScriptBuiltIn {
  static Future<RunVariable> run(String name, List<RunVariable> args) async {
    const refMap = {
      'printv': [printv, -1],
      'split': [strSplit, 2],
    };

    if (!refMap.containsKey(name))
      throw Exception('[RUNNER-FUNCTION] $name function not found!');

    var item = refMap[name];

    if (item[1] as int > 0 && args.length != item[1] as int)
      throw Exception(
          '[RUNNER-FUNCTION] $name arguments count is not matched!');

    return await (item[0] as FunctionCallback)(args);
  }

  static _printInternal(RunVariable rv) {
    if (rv.isString)
      print("${rv.value as String}");
    else if (rv.isInteger)
      print(rv.value as int);
    else if (rv.isList) {
      print('[');
      for (var i = 0; i < rv.length(); i++) {
        _printInternal(rv.index(i));
        if (i != rv.length() - 1) print(',');
      }
      print(']');
    }
  }

  static Future<RunVariable> printv(List<RunVariable> args) async {
    for (var a in args) _printInternal(a);

    return RunVariable(isReady: false);
  }

  static Future<RunVariable> strSplit(List<RunVariable> args) async {
    if (!args[0].isString && !args[1].isString)
      throw Exception('[RUNNER-FUNCTION] Split argument type error!');

    return RunVariable(
        isList: true,
        listValue: (args[0].value as String)
            .split(args[1].value as String)
            .map((e) => RunVariable(isConst: true, isString: true, value: e))
            .toList());
  }
}
