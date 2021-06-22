// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';

final defaultTitle = 'Project Violet';

Future<void> showOkDialog(BuildContext context, String message,
    [String title]) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title ?? defaultTitle),
      content: SelectableText(message),
      actions: [
        TextButton(
          style: TextButton.styleFrom(primary: Settings.majorColor),
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(Translations.of(context).trans('ok')),
        ),
      ],
    ),
  );
}

Future<bool> showYesNoDialog(BuildContext context, String message,
    [String title]) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title ?? defaultTitle),
      content: Text(message),
      actions: [
        TextButton(
          style: TextButton.styleFrom(primary: Settings.majorColor),
          onPressed: () {
            Navigator.pop(context, true);
          },
          child: Text(Translations.of(context).trans('yes')),
        ),
        TextButton(
          style: TextButton.styleFrom(primary: Settings.majorColor),
          onPressed: () {
            Navigator.pop(context, false);
          },
          child: Text(Translations.of(context).trans('no')),
        ),
      ],
    ),
  );
}
