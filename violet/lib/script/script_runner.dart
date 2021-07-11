// This source code is a part of Project Violet.
// Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/script/parse_tree.dart';
import 'package:violet/script/script_lexer.dart';
import 'package:violet/script/script_model.dart';
import 'package:violet/script/script_parser.dart';

class _Variable {
  final bool isList;
  final bool isConst;
  final bool isVariable;

  bool isString;
  bool isInteger;

  _Variable({
    this.isConst = false,
    this.isList = false,
    this.isVariable = false,
    this.isString,
    this.isInteger,
    this.value,
  }) {
    if (this.isList) _list = <_Variable>[];
  }

  List<_Variable> _list;

  Object value;

  _Variable index(int index) {
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

    _stack = <Map<String, _Variable>>[];
    _pushStack();
    _runBlock(node as PBlock);
    _popStack();
  }

  List<Map<String, _Variable>> _stack;

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
        var v1 = await _runIndex(stat.index1);
        var v2 = await _runIndex(stat.index2);

        if (!(v1.isVariable || v1.isList))
          throw Exception('[RUNNER] Cannot assign index to not varialbe value');

        if (v1.isList) {
          if (!v2.isList)
            throw Exception('[RUNNER] Not match left and right value type');
          v1._list = v2._list;
        } else if (v2.isConst) {
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

  Future<_Variable> _runIndex(PIndex index) async {
    var v1 = await _runVariable(index.variable1);
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

  Future<_Variable> _runVariable(PVariable variable) async {
    if (variable.content is PFunction) {
      return await _runFunction(variable.content as PFunction);
    } else if (variable.content is PVariable) {
      // TODO: handle variable correctly
      return await _runVariable(variable.content as PVariable);
    } else {
      var v = variable.content as String;
      var i = int.tryParse(v);

      if (i != null) return _Variable(isConst: true, isInteger: true, value: i);
      return _Variable(isConst: true, isString: true, value: v);
    }
  }

  Future<void> _runArgument(PArgument arg) async {}

  Future<_Variable> _runFunction(PFunction func) async {}

  Future<void> _runRunnable(PRunnable runnable) async {}
}
