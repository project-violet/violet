// This source code is a part of Project Violet.
// Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:tuple/tuple.dart';

abstract class Lexer {
  List<List<int>> transitionTable;
  List<String> acceptTable;

  Lexer({
    this.transitionTable,
    this.acceptTable,
  });

  String target;
  int pos = 0;
  bool err = false;
  int latestPos;
  List<int> errPos;
  int currentLine;
  int currentColumn;

  void allocateTarget(String literal) {
    target = literal;
    pos = 0;
    currentLine = 0;
    currentColumn = 0;
    errPos = <int>[];
    err = false;
  }

  bool valid() => pos < target.length;

  bool error() => err;

  Tuple4<String, String, int, int> next() {
    var builder = '';
    var nodePos = 0;
    latestPos = pos;

    int curLine = currentLine;
    int curColumn = currentColumn;

    for (; pos < target.length; pos++) {
      var tt = target[pos].codeUnits;
      var ttCh = tt[0];
      if (tt.length > 1) ttCh = 'a'.codeUnits[0];
      int nextTransition = transitionTable[nodePos][ttCh];

      switch (nextTransition) {
        case -1:
          // No-name
          if (acceptTable[nodePos] == "") {
            // Drop string and initialization
            builder = '';
            latestPos = pos;
            pos--;
            nodePos = 0;
            currentColumn--;
            curLine = currentLine;
            curColumn = currentColumn;
            continue;
          }
          if (acceptTable[nodePos] == null) {
            err = true;
            errPos.add(pos);
            continue;
          }
          return Tuple4<String, String, int, int>(
              acceptTable[nodePos], builder, curLine + 1, curColumn + 1);

        default:
          if (target[pos] == '\n') {
            currentLine++;
            currentColumn = 1;
          } else
            currentColumn++;
          builder += target[pos];
          break;
      }

      nodePos = nextTransition;
    }
    if (acceptTable[nodePos] == null)
      throw new Exception(
          "[SCANNER] Pattern not found! L:$curLine, C:$curColumn, D:'$builder'");
    return Tuple4<String, String, int, int>(
        acceptTable[nodePos], builder, curLine + 1, curColumn + 1);
  }
}
