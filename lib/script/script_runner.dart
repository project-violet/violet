// This source code is a part of Project Violet.
// Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/script/parse_tree.dart';
import 'package:violet/script/script_builtin.dart';
import 'package:violet/script/script_lexer.dart';
import 'package:violet/script/script_model.dart';
import 'package:violet/script/script_parser.dart';

class RunVariable {
  final bool isList;
  final bool isConst;
  final bool isVariable;

  bool isString;
  bool isInteger;

  bool isReady;

  RunVariable({
    this.isConst = false,
    this.isList = false,
    this.isVariable = false,
    this.isString,
    this.isInteger,
    this.isReady = true,
    this.value,
  }) {
    if (this.isList) _list = <RunVariable>[];
  }

  List<RunVariable> _list;

  Object value;

  RunVariable index(int index) {
    return _list[index];
  }

  int length() => _list.length;
}

class ScriptRunner {
  ParseTree _tree;

  ScriptRunner(String script) {
    _doParse(script);
  }

  _doParse(String script) {
    var lexer = ScriptLexer();
    var parser = ScriptParser();

    lexer.allocateTarget(script);

    var insert = (String x, String y, int a, int b) {
      parser.insertByTokenName(x, y);
      if (parser.isError())
        throw new Exception("[COMPILER] Parser error! L:$a, C:$b");
      while (parser.reduce()) {
        var l = parser.latestReduce();
        l.action(l);
        parser.insertByTokenName(x, y);
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

  runScript(Map<String, Object> variables) {
    var node = _tree.root.userContents as INode;

    if (!(node is PBlock))
      throw new Exception("[RUNNER] Error cannot continue!");

    _stack = <Map<String, RunVariable>>[];
    _pushStack();
    _runBlock(node as PBlock);
    _popStack();
  }

  List<Map<String, RunVariable>> _stack;

  _pushStack() {
    _stack.add(Map<String, Object>());
  }

  _popStack() {
    _stack.removeLast();
  }

  Future<void> _runBlock(PBlock block) async {
    if (block.isEmpty) return;

    if (block.isInnerBlock) {
      _pushStack();
      await _runBlock(block.block);
      _popStack();
    } else if (block.isLine) {
      await _runLine(block.line);
      await _runBlock(block.block);
    }
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
          throw Exception('[RUNNER] Cannot assign index to not variable value');

        if (v1.isReady) {
          if (v1.isList) {
            if (!v2.isList)
              throw Exception('[RUNNER] Not match left and right value type');
            v1._list = v2._list;
          } else if (v2.isConst) {
            v1.value = v2.value;
            v1.isString = v2.isString;
            v1.isInteger = v2.isInteger;
          }
        } else {
          if (!v2.isReady) {
            throw Exception(
                '[RUNNER] Cannot assign index to not ready variable.');
          }
          v1.isReady = true;
          v1._list = v2._list;
          v1.value = v2.value;
          v1.isString = v2.isString;
          v1.isInteger = v2.isInteger;
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
    var v1 = await _runVariable(index.variable1, isLeftVariable);
    if (!index.isIndexing) return v1;

    var v2 = await _runVariable(index.variable2);

    if (!v1.isList)
      throw Exception('[RUNNER] Cannot indexing by not list value');
    if (!v2.isInteger)
      throw Exception('[RUNNER] Cannot indexing by not integer value');
    if (v1.length() >= (v2.value as int))
      throw Exception('[RUNNER] Overflow, cannot index over list length');

    return v1.index(v2.value as int);
  }

  Future<RunVariable> _runVariable(PVariable variable,
      [bool isLeftVariable = false]) async {
    if (variable.content is PFunction) {
      return await _runFunction(variable.content as PFunction);
    } else if (variable.content is String) {
      var name = variable.content as String;
      for (var e in _stack.reversed) {
        if (e.containsKey(variable)) return e[name];
      }

      if (isLeftVariable) {
        var nv = RunVariable(isReady: false, isVariable: true);
        _stack.last[name] = nv;
        return nv;
      }

      // Variable Not Found!
      throw Exception('[RUNNER] $name variable is not found in this scope!');
    } else if (variable.content is PConsts) {
      var v = (variable.content as PConsts).content;
      var i = int.tryParse(v);

      if (i != null)
        return RunVariable(isConst: true, isInteger: true, value: i);
      return RunVariable(isConst: true, isString: true, value: v);
    }

    throw Exception('[RUNNER] Dead reaching!');
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
        var i2 = await _runIndex(runnable.index1);

        if (!i1.isInteger || !i2.isInteger)
          throw Exception('[RUNNER] Cannot looping by not integer value');

        var name = runnable.name;

        var ii1 = i1.value as int;
        var ii2 = i2.value as int;

        if (_stack.last.containsKey(name))
          throw Exception('[RUNNER] $name is already used!');

        _stack.last[name] =
            RunVariable(isVariable: true, isInteger: true, value: ii1);

        for (; ii1 <= ii2; ii1++) {
          _stack.last[name].value = ii1;
          await _runBlock(runnable.block1);
        }

        _stack.last.removeWhere((key, value) => key == name);

        break;
      case RunnableType.sforeach:
        var name = runnable.name;
        var index = await _runIndex(runnable.index1);

        if (!index.isList)
          throw Exception('[RUNNER] List type can only iterate.');

        if (_stack.last.containsKey(name))
          throw Exception('[RUNNER] $name is already used!');

        for (var i = 0; i < index.length(); i++) {
          _stack.last[name] = index.index(i);
        }

        _stack.last.removeWhere((key, value) => key == name);

        break;
      case RunnableType.sif:
        var cond = await _runIndex(runnable.index1);

        if (!cond.isInteger)
          throw Exception('[RUNNER] Cannot conditioning by not integer value');

        if (cond.value as int != 0) await _runBlock(runnable.block1);

        break;
      case RunnableType.sifelse:
        var cond = await _runIndex(runnable.index1);

        if (!cond.isInteger)
          throw Exception('[RUNNER] Cannot conditioning by not integer value');

        if (cond.value as int != 0)
          await _runBlock(runnable.block1);
        else
          await _runBlock(runnable.block2);

        break;
    }
  }
}
