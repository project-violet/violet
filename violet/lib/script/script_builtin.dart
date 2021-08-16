// This source code is a part of Project Violet.
// Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;

import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/script/script_runner.dart';

typedef FunctionCallback = Future Function(List<RunVariable>);

class ScriptBuiltIn {
  static Future<RunVariable> run(String name, List<RunVariable> args) async {
    const refMap = {
      'print': [print, -1],
      //
      'split': [strSplit, 2],
      'replace': [strReplace, 3],
      'concat': [strConcat, -1],
      'indexof': [strIndexOf, 2],
      'substr': [strSubstr, -1],
      'len': [strLen, 1],
      'trim': [strTrim, 1],
      'ltrim': [strLTrim, 1],
      'rtrim': [strRTrim, 1],
      'at': [strAt, 2],
      'isint': [strIsInt, 1],
      'toint': [strToInt, 1],
      //
      'mapcreate': [mapMapCreate, 0],
      'mapinsert': [mapMapInsert, 3],
      'mapfromjson': [mapFromJson, 1],
      //
      'tostring': [intToString, 1],
      'add': [intAdd, 2],
      'sub': [intSub, 2],
      'mul': [intMul, 2],
      'div': [intDiv, 2],
      'remain': [intRemain, 2],
      //
      'and': [logicAnd, 2],
      'or': [logicOr, 2],
      'xor': [logicXor, 2],
      'not': [logicNot, 1],
      'gr': [logicGr, 2],
      'gre': [logicGre, 2],
      'ls': [logicLs, 2],
      'lse': [logicLse, 2],
      'eq': [logicEq, 2],
      'neq': [logicNeq, 2],
      'contains': [logicStringContains, 2],
      'containsKey': [logicMapContainsKey, 2],
      //
      'insert': [listInsert, 2],
      'append': [listAppend, 1],
      'removeat': [listRemoveAt, 1],
      'listfromjson': [listFromJson, 1],
      //
      'download': [httpDownload, -1]
    };

    if (!refMap.containsKey(name))
      throw Exception('[RUNNER-FUNCTION] $name function not found!');

    var item = refMap[name];

    if (item[1] as int >= 0 && args.length != item[1] as int)
      throw Exception(
          '[RUNNER-FUNCTION] $name arguments count is not matched!');

    return await (item[0] as FunctionCallback)(args);
  }

  static _printInternal(RunVariable rv, [String pad = '']) {
    if (rv.isString)
      core.print(pad + '${rv.value as String}');
    else if (rv.isInteger)
      core.print(pad + (rv.value as int).toString());
    else if (rv.isList) {
      core.print(pad + '[');
      for (var i = 0; i < rv.length(); i++) {
        _printInternal(rv.index(i), pad + '        ');
        if (i != rv.length() - 1) core.print(',');
      }
      core.print(pad + ']');
    } else if (rv.isMap) {
      core.print(pad + '{');
      var iter = rv.mapIter();
      var len = iter.length;
      var i = 0;
      for (var kv in rv.mapIter()) {
        core.print(pad + '    ' + '\"${kv.key}\":');
        _printInternal(kv.value, pad + '        ');
        if (i != len - 1) core.print(pad + '    ' + ',');
        i++;
      }
      core.print(pad + '}');
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
    if (args.any((element) => element.isList || element.isMap))
      throw Exception(
          '[RUNNER-FUNCTION] Concat arguments must be integer or string type!');

    return RunVariable(
      isVariable: true,
      isString: true,
      value: args.map((e) => e.value.toString()).join(""),
    );
  }

  static Future<RunVariable> strIndexOf(List<RunVariable> args) async {
    if (!args[0].isString && !args[1].isString)
      throw Exception(
          '[RUNNER-FUNCTION] IndexOf arguments must be string type!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as String).indexOf(args[1].value as String),
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

  static List<RunVariable> _fromListJsonInternal(List<dynamic> jsonArray) {
    return jsonArray.map((e) {
      if (e is String) {
        return RunVariable(
          isVariable: true,
          isString: true,
          value: e,
        );
      } else if (e is int) {
        return RunVariable(
          isVariable: true,
          isInteger: true,
          value: e,
        );
      } else if (e is Map<String, dynamic>) {
        return RunVariable(
          isMap: true,
          isVariable: true,
          mapValue: _fromMapJsonInternal(e),
        );
      } else if (e is List<dynamic>) {
        return RunVariable(
          isList: true,
          isVariable: true,
          listValue: _fromListJsonInternal(e),
        );
      }
    }).toList();
  }

  static Map<String, RunVariable> _fromMapJsonInternal(
      Map<String, dynamic> jsonOption) {
    var result = Map<String, RunVariable>();

    for (var kv in jsonOption.entries) {
      if (kv.value is String) {
        result[kv.key] = RunVariable(
          isVariable: true,
          isString: true,
          value: kv.value as String,
        );
      } else if (kv.value is int) {
        result[kv.key] = RunVariable(
          isVariable: true,
          isInteger: true,
          value: kv.value as int,
        );
      } else if (kv.value is Map<String, dynamic>) {
        result[kv.key] = RunVariable(
          isMap: true,
          isVariable: true,
          mapValue: _fromMapJsonInternal(kv.value as Map<String, dynamic>),
        );
      } else if (kv.value is List<dynamic>) {
        result[kv.key] = RunVariable(
          isList: true,
          isVariable: true,
          listValue: _fromListJsonInternal(kv.value as List<dynamic>),
        );
      }
    }

    return result;
  }

  static Future<RunVariable> mapFromJson(List<RunVariable> args) async {
    if (!args[0].isString)
      throw Exception('[RUNNER-FUNCTION] MapFromJson argument type error!');

    var json = jsonDecode(args[0].value as String);

    if (!(json is Map<String, dynamic>))
      throw Exception(
          '[RUNNER-FUNCTION] MapFromJson only parse json_option! Try ListFromJson!');

    return RunVariable(
      isVariable: true,
      isMap: true,
      mapValue: _fromMapJsonInternal(json as Map<String, dynamic>),
    );
  }

  /*----------------------------------------------------------------

                         Integer Functions

  ----------------------------------------------------------------*/

  static Future<RunVariable> intToString(List<RunVariable> args) async {
    if (!args[0].isInteger)
      throw Exception('[RUNNER-FUNCTION] ToString argument type error!');

    return RunVariable(
      isVariable: true,
      isString: true,
      value: (args[0].value as int).toString(),
    );
  }

  static Future<RunVariable> intAdd(List<RunVariable> args) async {
    if (!args[0].isInteger && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] Add argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as int) + (args[1].value as int),
    );
  }

  static Future<RunVariable> intSub(List<RunVariable> args) async {
    if (!args[0].isInteger && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] Subtract argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as int) - (args[1].value as int),
    );
  }

  static Future<RunVariable> intMul(List<RunVariable> args) async {
    if (!args[0].isInteger && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] Multiple argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as int) * (args[1].value as int),
    );
  }

  static Future<RunVariable> intDiv(List<RunVariable> args) async {
    if (!args[0].isInteger && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] Divide argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as int) ~/ (args[1].value as int),
    );
  }

  static Future<RunVariable> intRemain(List<RunVariable> args) async {
    if (!args[0].isInteger && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] Remain argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as int) % (args[1].value as int),
    );
  }

  /*----------------------------------------------------------------

                           Logic Functions

  ----------------------------------------------------------------*/

  static Future<RunVariable> logicAnd(List<RunVariable> args) async {
    if (!args[0].isInteger && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] Logic And argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as int) != 0 && (args[1].value as int) != 0 ? 1 : 0,
    );
  }

  static Future<RunVariable> logicOr(List<RunVariable> args) async {
    if (!args[0].isInteger && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] Logic Or argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as int) != 0 || (args[1].value as int) != 0 ? 1 : 0,
    );
  }

  static Future<RunVariable> logicNot(List<RunVariable> args) async {
    if (!args[0].isInteger)
      throw Exception('[RUNNER-FUNCTION] Logic Not argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as int) != 0 ? 0 : 1,
    );
  }

  static Future<RunVariable> logicXor(List<RunVariable> args) async {
    if (!args[0].isInteger && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] Logic Xor argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: ((args[0].value as int) != 0) != ((args[1].value as int) != 0)
          ? 1
          : 0,
    );
  }

  static Future<RunVariable> logicGr(List<RunVariable> args) async {
    if (!args[0].isInteger && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] Logic Gr argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as int) > (args[1].value as int) ? 1 : 0,
    );
  }

  static Future<RunVariable> logicGre(List<RunVariable> args) async {
    if (!args[0].isInteger && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] Logic Gre argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as int) >= (args[1].value as int) ? 1 : 0,
    );
  }

  static Future<RunVariable> logicLs(List<RunVariable> args) async {
    if (!args[0].isInteger && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] Logic Ls argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as int) < (args[1].value as int) ? 1 : 0,
    );
  }

  static Future<RunVariable> logicLse(List<RunVariable> args) async {
    if (!args[0].isInteger && !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] Logic Lse argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as int) <= (args[1].value as int) ? 1 : 0,
    );
  }

  static Future<RunVariable> logicEq(List<RunVariable> args) async {
    if (args[0].isInteger != args[1].isInteger ||
        args[0].isString != args[1].isString)
      throw Exception('[RUNNER-FUNCTION] Logic Eq argument type error!');

    if (args[0].isInteger)
      return RunVariable(
        isVariable: true,
        isInteger: true,
        value: (args[0].value as int) == (args[1].value as int) ? 1 : 0,
      );

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as String) == (args[1].value as String) ? 1 : 0,
    );
  }

  static Future<RunVariable> logicNeq(List<RunVariable> args) async {
    if (args[0].isInteger != args[1].isInteger ||
        args[0].isString != args[1].isString)
      throw Exception('[RUNNER-FUNCTION] Logic Neq argument type error!');

    if (args[0].isInteger)
      return RunVariable(
        isVariable: true,
        isInteger: true,
        value: (args[0].value as int) != (args[1].value as int) ? 1 : 0,
      );

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: (args[0].value as String) != (args[1].value as String) ? 1 : 0,
    );
  }

  static Future<RunVariable> logicStringContains(List<RunVariable> args) async {
    if (!args[0].isString && !args[1].isString)
      throw Exception(
          '[RUNNER-FUNCTION] Logic String Contains argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value:
          (args[0].value as String).contains(args[1].value as String) ? 1 : 0,
    );
  }

  static Future<RunVariable> logicMapContainsKey(List<RunVariable> args) async {
    if (!args[0].isMap && !args[1].isString)
      throw Exception(
          '[RUNNER-FUNCTION] Logic ContainsKey argument type error!');

    return RunVariable(
      isVariable: true,
      isInteger: true,
      value: args[0].containsKey(args[1].value as String) ? 1 : 0,
    );
  }

  /*----------------------------------------------------------------

                         List Functions

  ----------------------------------------------------------------*/

  static Future<RunVariable> listFromJson(List<RunVariable> args) async {
    if (!args[0].isString)
      throw Exception('[RUNNER-FUNCTION] ListFromJson argument type error!');

    var json = jsonDecode(args[0].value as String);

    if (!(json is List<dynamic>))
      throw Exception(
          '[RUNNER-FUNCTION] ListFromJson only parse json_array! Try ListFromJson!');

    return RunVariable(
      isVariable: true,
      isList: true,
      listValue: _fromListJsonInternal(json as List<dynamic>),
    );
  }

  static Future<RunVariable> listInsert(List<RunVariable> args) async {
    if (!args[0].isList || !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] List Insert argument type error!');

    args[0].insert(args[2], args[1].value as int);

    return RunVariable(isReady: false);
  }

  static Future<RunVariable> listAppend(List<RunVariable> args) async {
    if (!args[0].isList)
      throw Exception('[RUNNER-FUNCTION] List Append argument type error!');

    args[0].append(args[1]);

    return RunVariable(isReady: false);
  }

  static Future<RunVariable> listRemoveAt(List<RunVariable> args) async {
    if (!args[0].isList || !args[1].isInteger)
      throw Exception('[RUNNER-FUNCTION] List RemoveAt argument type error!');

    args[0].removeAt(args[1].value as int);

    return RunVariable(isReady: false);
  }

  /*----------------------------------------------------------------

                           Http Functions

  ----------------------------------------------------------------*/

  static Future<RunVariable> httpDownload(List<RunVariable> args) async {
    if (args.length >= 3 ||
        !args[0].isString ||
        (args.length == 2 && !args[1].isMap))
      throw Exception('[RUNNER-FUNCTION] HTTP Download argument type error!');

    if (args.length == 1) {
      var res = await http.get(args[0].value as String);

      return RunVariable(isVariable: true, isString: true, value: res.body);
    } else {
      var iter = args[1].mapIter();

      var header = Map<String, String>();
      iter.forEach(
          (element) => header[element.key] = element.value.value as String);

      var res = await http.get(args[0].value as String, headers: header);

      return RunVariable(isVariable: true, isString: true, value: res.body);
    }
  }
}
