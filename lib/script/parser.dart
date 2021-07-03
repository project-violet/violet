// This source code is a part of Project Violet.
// Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:tuple/tuple.dart';
import 'package:violet/script/parse_tree.dart';

class ParserAction {
  SemanticAction semanticAction;
  ParserAction(this.semanticAction);
  static ParserAction create(SemanticAction action) => ParserAction(action);
}

abstract class ShiftReduceParser {
  Map<String, int> symbolTable;
  List<List<int>> table;
  List<int> production;
  List<int> groupTable;
  int accept;

  ShiftReduceParser({
    this.symbolTable,
    this.table,
    this.production,
    this.groupTable,
    this.accept,
    this.actions,
  }) {
    var ll = symbolTable.entries
        .map((kv) => Tuple2<int, String>(kv.value, kv.key))
        .toList();
    ll.sort((x, y) => x.item1.compareTo(y.item1));
    _symbolIndexName = ll.map((e) => e.item2).toList();
  }

  List<String> _symbolIndexName;
  List<int> _stateStack = <int>[];
  List<ParseTreeNode> _treenodeStack = <ParseTreeNode>[];
  List<ParserAction> actions;

  bool _latestError;
  bool _latestReduce;
  bool isAccept() => _stateStack.length == 0;
  bool isError() => _latestError;
  bool reduce() => _latestReduce;

  ParseTree tree() => new ParseTree(_treenodeStack.last);

  void clear() {
    _latestError = _latestReduce = false;
    _stateStack.clear();
    _treenodeStack.clear();
  }

  void insertByTokenName(String tokenName, String contents) =>
      insertByIndex(symbolTable[tokenName], contents);
  void insertByIndex(int index, String contents) {
    if (_stateStack.length == 0) {
      _stateStack.add(0);
      _latestError = false;
    }
    _latestReduce = false;

    int code = table[_stateStack.last][index];

    if (code == accept) {
      // Nothing
    } else if (code > 0) {
      // Shift
      _stateStack.add(table[_stateStack.last][index]);
      _treenodeStack.add(ParseTreeNode.newNode(
          production: _symbolIndexName[index], contents: contents));
    } else if (code < 0) {
      // Reduce
      _reduce(index);
      _latestReduce = true;
    } else {
      // Panic mode
      _stateStack.clear();
      _treenodeStack.clear();
      _latestError = true;
    }
  }

  ParseTreeNode latestReduce() => _treenodeStack.last;
  void _reduce(int index) {
    var reduceProduction = -table[_stateStack.last][index];
    var reduceTreenodes = <ParseTreeNode>[];

    // Reduce Stack
    for (int i = 0; i < production[reduceProduction]; i++) {
      _stateStack.removeLast();
      reduceTreenodes.insert(0, _treenodeStack.removeLast());
    }

    _stateStack.add(table[_stateStack.last][groupTable[reduceProduction]]);

    var reductionParent = ParseTreeNode.newNode(
        production: _symbolIndexName[groupTable[reduceProduction]]);
    reductionParent.productionRuleIndex = reduceProduction - 1;
    reduceTreenodes.forEach((x) => x.parent = reductionParent);
    reductionParent.contents = reduceTreenodes.map((x) => x.contents).join();
    reductionParent.childs = reduceTreenodes;
    _treenodeStack.add(reductionParent);
    if (actions != null && actions.length != 0)
      reductionParent.action =
          actions[reductionParent.productionRuleIndex].semanticAction;
  }
}
