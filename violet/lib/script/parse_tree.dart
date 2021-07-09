// This source code is a part of Project Violet.
// Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

typedef SemanticAction = void Function(ParseTreeNode);

class ParseTreeNode {
  String production;
  String contents;
  Object userContents;
  int productionRuleIndex;
  ParseTreeNode parent;
  List<ParseTreeNode> childs;
  SemanticAction action;

  ParseTreeNode({this.parent, this.childs, this.production, this.contents});

  static ParseTreeNode newNode({String production, String contents}) =>
      new ParseTreeNode(
        parent: null,
        childs: <ParseTreeNode>[],
        production: production,
        contents: contents,
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
      builder[0] += node.production + " " + node.contents + "\r\n";
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
      builder[0] += node.production + " " + node.contents + "\r\n";
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
