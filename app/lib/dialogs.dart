// This source code is a part of Project Violet.
// Copyright (C) 2020. rollrat. Licensed under the MIT Licence.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Dialogs {
  static Future okDialog(BuildContext context, String message, [String title]) async {
    title ??= 'Project Violet';
    Widget okButton = FlatButton(
      child: Text("확인"),
      onPressed: () {
        Navigator.pop(context, "OK");
      },
    );
    AlertDialog alert = AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        okButton,
      ],
    );
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  static Future<bool> yesnoDialog(BuildContext context, String message, [String title]) async {
    title ??= 'Project Violet';
    Widget yesButton = FlatButton(
      child: Text("예"),
      onPressed: () {
        Navigator.pop(context, true);
      },
    );
    Widget noButton = FlatButton(
      child: Text("아니오"),
      onPressed: () {
        Navigator.pop(context, false);
      },
    );
    AlertDialog alert = AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        yesButton,
        noButton,
      ],
    );
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    ) as bool;
  }
}
