// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:violet/locale.dart';
import 'package:violet/settings.dart';

class Dialogs {
  static Future okDialog(BuildContext context, String message,
      [String title]) async {
    title ??= 'Project Violet';
    Widget okButton = FlatButton(
      child: Text(Translations.of(context).trans('ok'),
          style: TextStyle(color: Settings.majorColor)),
      // color: Colors.purple,
      // highlightColor: Colors.purple,
      // hoverColor: Colors.purple,
      focusColor: Settings.majorColor,
      splashColor: Settings.majorColor.withOpacity(0.3),
      onPressed: () {
        Navigator.pop(context, "OK");
      },
    );
    AlertDialog alert = AlertDialog(
      title: Text(title),
      content: SelectableText(message),
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

  static Future<bool> yesnoDialog(BuildContext context, String message,
      [String title]) async {
    title ??= 'Project Violet';
    Widget yesButton = FlatButton(
      child: Text(Translations.of(context).trans('yes'),
          style: TextStyle(color: Settings.majorColor)),
      focusColor: Settings.majorColor,
      splashColor: Settings.majorColor.withOpacity(0.3),
      onPressed: () {
        Navigator.pop(context, true);
      },
    );
    Widget noButton = FlatButton(
      child: Text(Translations.of(context).trans('no'),
          style: TextStyle(color: Settings.majorColor)),
      focusColor: Settings.majorColor,
      splashColor: Settings.majorColor.withOpacity(0.3),
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
