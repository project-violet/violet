// This source code is a part of Project Violet.
// Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/script/parse_tree.dart';
import 'package:violet/script/script_builtin.dart';
import 'package:violet/script/script_lexer.dart';
import 'package:violet/script/script_model.dart';
import 'package:violet/script/script_parser.dart';

class RunVariable {
  bool isConst;
  bool isVariable;

  bool isList;
  bool isString;
  bool isInteger;
  bool isMap;

  bool isReady;

  RunVariable({
    this.isConst = false,
    this.isList = false,
    this.isVariable = false,
    this.isString = false,
    this.isInteger = false,
    this.isMap = false,
    this.isReady = true,
    List<RunVariable> listValue,
    Map<String, RunVariable> mapValue,
    this.value,
  }) {
    if (this.isList) {
      if (listValue == null)
        _list = <RunVariable>[];
      else
        _list = listValue;
    }

    if (this.isMap) {
      if (mapValue == null)
        _map = Map<String, RunVariable>();
      else
        _map = mapValue;
    }
  }

  Map<String, RunVariable> _map;
  List<RunVariable> _list;

  RunVariable index(int index) => _list[index];
  RunVariable map(String key) => _map[key];

  void mapSet(String key, RunVariable variable) => _map[key] = variable;

  Iterable<MapEntry<String, RunVariable>> mapIter() => _map.entries;

  bool containsKey(String key) => _map.containsKey(key);

  void append(RunVariable variable) => _list.add(variable);
  void insert(RunVariable variable, int pos) => _list.insert(pos, variable);
  void removeAt(int pos) => _list.removeAt(pos);

  Object value;

  int length() => _list.length;

  static RunVariable fromInt(int value) =>
      RunVariable(isVariable: true, isInteger: true, value: value);
  static RunVariable fromString(String value) =>
      RunVariable(isVariable: true, isString: true, value: value);

  static dynamic _toElement(RunVariable rv) {
    if (rv.isInteger) return rv.value as int;
    if (rv.isString) return rv.value as String;
    if (rv.isList) return rv._list.map((e) => _toElement(e)).toList();
    if (rv.isMap) {
      var map = Map<String, dynamic>();
      rv._map.entries.map((e) => map[e.key] = _toElement(e.value));
      return map;
    }

    throw Exception('[RUNVARIABLE] Dead reaching!');
  }

  List<dynamic> toList() {
    if (!isList)
      throw Exception('[RUNVARIABLE] You cannot port this variable to list!');
    return _toElement(this) as List<dynamic>;
  }

  Map<String, dynamic> toMap() {
    if (!isMap)
      throw Exception('[RUNVARIABLE] You cannot port this variable to map!');
    return _toElement(this) as Map<String, dynamic>;
  }
}

class ScriptRunner {
  ParseTree _tree;

  ScriptRunner(String script) {
    _doParse(script.trim());
  }

  _doParse(String script) {
    var lexer = ScriptLexer();
    var parser = ScriptParser();

    lexer.allocateTarget("[$script]");

    var insert = (String x, String y, int a, int b) {
      parser.insertByTokenName(x, y, a, b);
      if (parser.isError())
        throw new Exception("[COMPILER] Parser error! L:$a, C:$b");
      while (parser.reduce()) {
        var l = parser.latestReduce();
        l.action(l);
        (l.userContents as INode).lineNumber = l.line;
        (l.userContents as INode).columNumber = l.column;
        parser.insertByTokenName(x, y, a, b);
        if (parser.isError())
          throw new Exception("[COMPILER] Parser error! L:$a, C:$b");
      }
    };

    while (lexer.valid()) {
      var tk = lexer.next();
      insert(tk.item1, tk.item2, tk.item3, tk.item4);
    }

    if (parser.isError()) throw new Exception("[COMPILER] Parser error! inf");
    insert("\$", "\$", -1, -1);

    _tree = parser.tree();
  }

  printTree() {
    return _tree.printTree();
  }

  Future<void> runScript(Map<String, RunVariable> variables) async {
    var node = _tree.root.userContents as INode;

    if (!(node is PBlockEntry))
      throw new Exception("[RUNNER] Error cannot continue!");

    _stack = <Map<String, RunVariable>>[];
    _stack.add(variables);
    _pushStack();
    await _runBlockEntry(node as PBlockEntry);
    // _popStack();
  }

  RunVariable getValue(String name) {
    for (var e in _stack.reversed) {
      if (e == null) continue;
      if (e.containsKey(name)) return e[name];
    }
    return null;
  }

  List<Map<String, RunVariable>> _stack;

  _pushStack() {
    _stack.add(Map<String, RunVariable>());
  }

  _popStack() {
    _stack.removeLast();
  }

  Future<void> _runBlockEntry(PBlockEntry blockEntry) async {
    if (blockEntry.isInnerBlock) {
      _pushStack();
      await _runBlock(blockEntry.block);
      _popStack();
    } else if (blockEntry.isLine) {
      await _runLine(blockEntry.line);
    }
  }

  Future<void> _runBlock(PBlock block) async {
    if (block.isEmpty) return;

    await _runLine(block.line);
    await _runBlock(block.block);
  }

  Future<void> _runStatement(PStatement stat) async {
    switch (stat.type) {
      case StatementType.sfunction:
        await _runFunction(stat.function);
        break;
      case StatementType.sindex:
        var v1 = await _runIndex(stat.index1, true);
        var v2 = await _runIndex(stat.index2);

        if (!(v1.isVariable || v1.isList))
          throw Exception('[RUNNER] Cannot assign index to not variable value' +
              ' ${stat.getLC()}');

        if (v1.isReady) {
          if (v1.isList) {
            if (!v2.isList)
              throw Exception('[RUNNER] Not match left and right value type' +
                  ' ${stat.getLC()}');
            v1._list = v2._list;
          } else if (v2.isConst) {
            v1.value = v2.value;
            v1.isString = v2.isString;
            v1.isInteger = v2.isInteger;
          }
        } else {
          if (!v2.isReady) {
            throw Exception(
                '[RUNNER] Cannot assign index to not ready variable.' +
                    ' ${stat.getLC()}');
          }
          v1.isReady = true;
          v1._list = v2._list;
          v1._map = v2._map;
          v1.value = v2.value;
          v1.isString = v2.isString;
          v1.isInteger = v2.isInteger;
          v1.isList = v2.isList;
          v1.isConst = v2.isConst;
          v1.isVariable = v2.isVariable;
          v1.isMap = v2.isMap;
        }

        break;
      case StatementType.srunnable:
        await _runRunnable(stat.runnable);
        break;
    }
  }

  Future<void> _runLine(PLine line) async {
    await _runStatement(line.statement);
  }

  Future<RunVariable> _runIndex(PIndex index,
      [bool isLeftVariable = false]) async {
    if (!index.isIndexing) {
      return await _runVariable(index.variable, isLeftVariable);
    }

    var v1 = await _runIndex(index.index);
    var v2 = await _runVariable(index.variable);

    if (v1.isList) {
      if (!v2.isInteger)
        throw Exception('[RUNNER] Cannot indexing by not integer value' +
            ' ${index.getLC()}');
      if (v1.length() <= (v2.value as int))
        throw Exception('[RUNNER] Overflow, cannot index over list length' +
            ' ${index.getLC()}');

      return v1.index(v2.value as int);
    } else if (v1.isMap) {
      if (!v2.isString)
        throw Exception('[RUNNER] Cannot mapping by not string value' +
            ' ${index.getLC()}');

      var v = v1.map(v2.value as String);

      if (v == null)
        throw Exception('[RUNNER] Key ${v2.value} is not found on map ' +
            ' ${index.getLC()}');

      return v;
    }

    throw Exception(
        '[RUNNER] Cannot indexing or mapping by not list or map value' +
            ' ${index.getLC()}');
  }

  Future<RunVariable> _runVariable(PVariable variable,
      [bool isLeftVariable = false]) async {
    if (variable.content is PFunction) {
      return await _runFunction(variable.content as PFunction);
    } else if (variable.content is String) {
      var name = variable.content as String;
      for (var e in _stack.reversed) {
        if (e == null) continue;
        if (e.containsKey(name)) return e[name];
      }

      if (isLeftVariable) {
        var nv = RunVariable(isReady: false, isVariable: true);
        _stack.last[name] = nv;
        return nv;
      }

      // Variable Not Found!
      throw Exception('[RUNNER] $name variable is not found in this scope!' +
          ' ${variable.getLC()}');
    } else if (variable.content is PConsts) {
      var c = (variable.content as PConsts);

      if (c.isInteger)
        return RunVariable(
          isConst: true,
          isInteger: true,
          value: int.parse(c.content as String),
        );
      return RunVariable(
        isConst: true,
        isString: true,
        value: (c.content as String),
      );
    }

    throw Exception('[RUNNER] Dead reaching!' + ' ${variable.getLC()}');
  }

  Future<List<RunVariable>> _runArgument(PArgument arg) async {
    if (arg.argument == null) {
      return [await _runIndex(arg.index)].toList();
    }

    var i = await _runIndex(arg.index);
    var a = await _runArgument(arg.argument);

    return [i] + a;
  }

  Future<RunVariable> _runFunction(PFunction func) async {
    var name = func.name;
    var args = <RunVariable>[];

    if (func.argument != null) {
      args = await _runArgument(func.argument);
    }

    return await ScriptBuiltIn.run(name, args);
  }

  Future<void> _runRunnable(PRunnable runnable) async {
    switch (runnable.type) {
      case RunnableType.sloop:
        var i1 = await _runIndex(runnable.index1);
        var i2 = await _runIndex(runnable.index2);

        if (!i1.isInteger || !i2.isInteger)
          throw Exception('[RUNNER] Cannot looping by not integer value' +
              ' ${runnable.getLC()}');

        var name = runnable.name;

        var ii1 = i1.value as int;
        var ii2 = i2.value as int;

        if (_stack.last.containsKey(name))
          throw Exception(
              '[RUNNER] $name is already used!' + ' ${runnable.getLC()}');

        _stack.last[name] =
            RunVariable(isVariable: true, isInteger: true, value: ii1);

        for (; ii1 <= ii2; ii1++) {
          _stack.last[name].value = ii1;
          await _runBlockEntry(runnable.blockEntry1);
        }

        _stack.last.removeWhere((key, value) => key == name);

        break;
      case RunnableType.sforeach:
        var name = runnable.name;
        var index = await _runIndex(runnable.index1);

        if (!index.isList)
          throw Exception(
              '[RUNNER] List type can only iterate.' + ' ${runnable.getLC()}');

        if (_stack.last.containsKey(name))
          throw Exception(
              '[RUNNER] $name is already used!' + ' ${runnable.getLC()}');

        for (var i = 0; i < index.length(); i++) {
          _stack.last[name] = index.index(i);
        }

        _stack.last.removeWhere((key, value) => key == name);

        break;
      case RunnableType.sif:
        var cond = await _runIndex(runnable.index1);

        if (!cond.isInteger)
          throw Exception('[RUNNER] Cannot conditioning by not integer value' +
              ' ${runnable.getLC()}');

        if (cond.value as int != 0) await _runBlockEntry(runnable.blockEntry1);

        break;
      case RunnableType.sifelse:
        var cond = await _runIndex(runnable.index1);

        if (!cond.isInteger)
          throw Exception('[RUNNER] Cannot conditioning by not integer value' +
              ' ${runnable.getLC()}');

        if (cond.value as int != 0)
          await _runBlockEntry(runnable.blockEntry1);
        else
          await _runBlockEntry(runnable.blockEntry2);

        break;
    }
  }
}
