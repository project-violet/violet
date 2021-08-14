// This source code is a part of Project Violet.
// Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;

import 'package:violet/script/script_runner.dart';

typedef FunctionCallback = Future Function(List<RunVariable>);

class ScriptBuiltIn {
  static Future<RunVariable> run(String name, List<RunVariable> args) async {
    const refMap = {
      'print': [print, -1],
      'split': [strSplit, 2],
      'replace': [strReplace, 3],
      'concat': [strConcat, -1],
      'substr': [strSubstr, -1],
      'len': [strLen, 1],
      'trim': [strTrim, 1],
      'ltrim': [strLTrim, 1],
      'rtrim': [strRTrim, 1],
      'at': [strAt, 2],
      'isint': [strIsInt, 1],
      'toint': [strToInt, 1],
      'mapcreate': [mapMapCreate, 0],
      'mapinsert': [mapMapInsert, 3],
    };

    if (!refMap.containsKey(name))
      throw Exception('[RUNNER-FUNCTION] $name function not found!');

    var item = refMap[name];

    if (item[1] as int >= 0 && args.length != item[1] as int)
      throw Exception(
          '[RUNNER-FUNCTION] $name arguments count is not matched!');

    return await (item[0] as FunctionCallback)(args);
  }

  static _printInternal(RunVariable rv) {
    if (rv.isString)
      core.print('${rv.value as String}');
    else if (rv.isInteger)
      core.print(rv.value as int);
    else if (rv.isList) {
      core.print('[');
      for (var i = 0; i < rv.length(); i++) {
        _printInternal(rv.index(i));
        if (i != rv.length() - 1) core.print(',');
      }
      core.print(']');
    } else if (rv.isMap) {
      core.print('{');
      var iter = rv.mapIter();
      var len = iter.length;
      var i = 0;
      for (var kv in rv.mapIter()) {
        core.print('\"${kv.key}\":');
        _printInternal(kv.value);
        if (i != len - 1) core.print(',');
        i++;
      }
      core.print('}');
    }
  }

  static Future<RunVariable> print(List<RunVariable> args) async {
    for (var a in args) _printInternal(a);

    return RunVariable(isReady: false);
  }

  /*----------------------------------------------------------------

                         String Functions

  ----------------------------------------------------------------*/

  static Future<RunVariable> strSplit(List<RunVariable> args) async {
    if (!args[0].isString && !args[1].isString)
      throw Exception('[RUNNER-FUNCTION] Split argument type error!');

    return RunVariable(
      isVariable: true,
      isList: true,
      listValue: (args[0].value as String)
          .split(args[1].value as String)
          .map((e) => RunVariable(isConst: true, isString: true, value: e))
          .toList(),
    );
  }

  static Future<RunVariable> strReplace(List<RunVariable> args) async {
    if (!args[0].isString && !args[1].isString && !args[2].isString)
      throw Exception('[RUNNER-FUNCTION] Replace argument type error!');

    return RunVariable(
      isVariable: true,
      isString: true,
      value: (args[0].value as String).replaceAll(
        args[1].value as String,
        args[2].value as String,
      ),
    );
  }

  static Future<RunVariable> strConcat(List<RunVariable> args) async {
    if (args.any((element) => element.isList))
      throw Exception(
          '[RUNNER-FUNCTION] Concat arguments must be integer or string type!');

    return RunVariable(
      isVariable: true,
      isString: true,
      value: args.map((e) => e.value.toString()).join(""),
    );
  }

  static Future<RunVariable> strSubstr(List<RunVariable> args) async {
    if (!args[0].isString && !args[1].isInteger ||
        args.length > 3 ||
        args.length <= 1 ||
        (args.length == 3 && !args[2].isInteger))
      throw Exception('[RUNNER-FUNCTION] Substr argument type error!');

    return RunVariable(
      isVariable: true,
      isString: true,
      value: args.length == 2
          ? (args[0].value as String).substring(args[1].value as int)
          : (args[0].value as String)
              .substring(args[1].value as int, args[2].value as int),
    );
  }

  static Future<RunVariable> strLen(List<RunVariable> args) async {
    if (!args[0].isString)
      throw Exception('[RUNNER-FUNCTION] Len argument type error!');

    core.print(args[0].value as String);

    return RunVariable(
      isInteger: true,
      isVariable: true,
      value: (args[0].value as String).length,
    );
  }

  static Future<RunVariable> strTrim(List<RunVariable> args) async {
    if (!args[0].isString)
      throw Exception('[RUNNER-FUNCTION] Trim argument type error!');

    return RunVariable(
      isVariable: true,
      isString: true,
      value: (args[0].value as String).trim(),
    );
  }

  static Future<RunVariable> strLTrim(List<RunVariable> args) async {
    if (!args[0].isString)
      throw Exception('[RUNNER-FUNCTION] LTrim argument type error!');

    return RunVariable(
      isVariable: true,
      isString: true,
      value: (args[0].value as String).trimLeft(),
    );
  }

  static Future<RunVariable> strRTrim(List<RunVariable> args) async {
    if (!args[0].isString)
      throw Exception('[RUNNER-FUNCTION] RTrim argument type error!');

    return RunVariable(
      isVariable: true,
      isString: true,
      value: (args[0].value as String).trimRight(),
    );
  }

  static Future<RunVariable> strAt(List<RunVariable> args) async {
    if (!args[0].isString && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] At argument type error!');

    return RunVariable(
      isVariable: true,
      isString: true,
      value: (args[0].value as String)[args[1].value as int],
    );
  }

  static Future<RunVariable> strIsInt(List<RunVariable> args) async {
    if (!args[0].isString)
      throw Exception('[RUNNER-FUNCTION] IsInt argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: int.tryParse(args[0].value as String) != null ? 1 : 0,
    );
  }

  static Future<RunVariable> strToInt(List<RunVariable> args) async {
    if (!args[0].isString)
      throw Exception('[RUNNER-FUNCTION] ToInt argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: int.parse(args[0].value as String),
    );
  }

  /*----------------------------------------------------------------

                          Map Functions

  ----------------------------------------------------------------*/

  static Future<RunVariable> mapMapCreate(List<RunVariable> args) async {
    return RunVariable(isVariable: true, isMap: true);
  }

  static Future<RunVariable> mapMapInsert(List<RunVariable> args) async {
    if (!args[0].isMap && !args[1].isString)
      throw Exception('[RUNNER-FUNCTION] MapInstert argument type error!');

    args[0].mapSet(args[1].value as String, args[2]);

    return RunVariable(isReady: false);
  }

  static Map<String, RunVariable> _fromJsonInternal(
      Map<String, dynamic> jsonOption) {}

  static Future<RunVariable> mapMapFromJson(List<RunVariable> args) async {
    if (!args[0].isString)
      throw Exception('[RUNNER-FUNCTION] MapFromJson argument type error!');

    var a = jsonDecode(args[0].value as String) as Map<String, dynamic>;

    return RunVariable(
      isMap: true,
      mapValue: _fromJsonInternal(jsonDecode(args[0].value as String)),
    );
  }

  /*----------------------------------------------------------------

                         Integer Functions

  ----------------------------------------------------------------*/

  /*----------------------------------------------------------------

                           Logic Functions

  ----------------------------------------------------------------*/

  /*----------------------------------------------------------------

                         List Functions

  ----------------------------------------------------------------*/

  /*----------------------------------------------------------------

                           Http Functions

  ----------------------------------------------------------------*/

}
