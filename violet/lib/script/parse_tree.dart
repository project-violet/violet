// This source code is a part of Project Violet.
// Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

typedef SemanticAction = void Function(ParseTreeNode);

class ParseTreeNode {
  String production;
  String contents;
  Object userContents;
  int productionRuleIndex;
  ParseTreeNode parent;
  int line;
  int column;
  List<ParseTreeNode> childs;
  SemanticAction action;

  ParseTreeNode({
    this.parent,
    this.childs,
    this.production,
    this.contents,
    this.line,
    this.column,
  });

  static ParseTreeNode newNode(
          {String production, String contents, int line, int column}) =>
      new ParseTreeNode(
        parent: null,
        childs: <ParseTreeNode>[],
        production: production,
        contents: contents,
        line: line,
        column: column,
      );

  void _innerPrint(
      List<String> builder, ParseTreeNode node, String indent, bool last) {
    builder[0] += indent;
    if (last) {
      builder[0] += "+-";
      indent += "  ";
    } else {
      builder[0] += "|-";
      indent += "| ";
    }

    if (node.childs.length == 0) {
      builder[0] += node.production +
          " " +
          node.contents +
          " (${node.line}, ${node.column})" +
          "\r\n";
    } else {
      builder[0] += node.production + "\r\n";
    }

    for (int i = 0; i < node.childs.length; i++)
      _innerPrint(builder, node.childs[i], indent, i == node.childs.length - 1);
  }

  String printSubTree() {
    var builder = [''];
    _innerPrint(builder, this, "", true);
    return builder[0];
  }

  updateLC(ParseTreeNode node) {
    line = node.line;
    column = node.column;
  }
}

class ParseTree {
  ParseTreeNode root;

  ParseTree(this.root);

  void _innerPrint(
      List<String> builder, ParseTreeNode node, String indent, bool last) {
    builder[0] += indent;
    if (last) {
      builder[0] += "+-";
      indent += "  ";
    } else {
      builder[0] += "|-";
      indent += "| ";
    }

    if (node.childs.length == 0) {
      builder[0] += node.production +
          " " +
          node.contents +
          " (${node.line}, ${node.column})" +
          "\r\n";
    } else {
      builder[0] += node.production + "\r\n";
    }

    for (int i = 0; i < node.childs.length; i++)
      _innerPrint(builder, node.childs[i], indent, i == node.childs.length - 1);
  }

  String printTree() {
    var builder = [''];
    _innerPrint(builder, root, "", true);
    return builder[0];
  }
}
