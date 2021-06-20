// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';

class Dialogs {
  static Future okDialog(BuildContext context, String message,
      [String title]) async {
    title ??= 'Project Violet';
    Widget okButton = TextButton(
      style: TextButton.styleFrom(primary: Settings.majorColor),
      onPressed: () {
        Navigator.pop(context, "OK");
      },
      child: Text(Translations.of(context).trans('ok')),
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
    Widget yesButton = TextButton(
      style: TextButton.styleFrom(primary: Settings.majorColor),
      onPressed: () {
        Navigator.pop(context, true);
      },
      child: Text(Translations.of(context).trans('yes')),
    );
    Widget noButton = TextButton(
      style: TextButton.styleFrom(primary: Settings.majorColor),
      onPressed: () {
        Navigator.pop(context, false);
      },
      child: Text(Translations.of(context).trans('no')),
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
