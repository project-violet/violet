// This source code is a part of Project Violet.
// Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/script/parse_tree.dart';
import 'package:violet/script/script_lexer.dart';
import 'package:violet/script/script_model.dart';
import 'package:violet/script/script_parser.dart';

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
    print(node.nodeType);
  }

  _runBlock(PBlock block) {}

  _runStatement(PStatement stat) {}

  _runLine(PLine line) {}

  _runIndex(PIndex index) {}

  _runVariable(PVariable variable) {}

  _runArgument(PArgument arg) {}

  _runFunction(PFunction func) {}

  _runRunnable(PRunnable runnable) {}
}
