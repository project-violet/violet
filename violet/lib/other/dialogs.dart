// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';

const defaultTitle = 'Project Violet';

Future<void> showOkDialog(BuildContext context, String message,
    [String? title]) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title ?? defaultTitle),
      content: SelectableText(message),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(Translations.instance!.trans('ok')),
        ),
      ],
    ),
  );
}

Future<bool> showOkCancelDialog({
  required BuildContext context,
  String? titleText,
  String? contentText,
  WidgetBuilder? contentBuilder,
  EdgeInsetsGeometry? contentPadding,
  String? okText,
  String? cancelText,
  VoidCallback? onOkPressed,
  VoidCallback? onCancelPressed,
  bool useRootNavigator = true,
}) async {
  assert((contentText != null && contentBuilder == null) ||
      (contentText == null && contentBuilder != null));

  return await showDialog(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (context) => AlertDialog(
      title: Text(titleText ?? defaultTitle),
      content: contentText != null
          ? Text(contentText)
          : Builder(builder: contentBuilder!),
      contentPadding: contentPadding!,
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
          onPressed: () {
            if (onOkPressed != null) {
              onOkPressed();
            } else {
              Navigator.pop(context, true);
            }
          },
          child: Text(okText ?? Translations.instance!.trans('ok')),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
          onPressed: () {
            if (onCancelPressed != null) {
              onCancelPressed();
            } else {
              Navigator.pop(context, false);
            }
          },
          child: Text(cancelText ?? Translations.instance!.trans('cancel')),
        ),
      ],
    ),
  );
}

Future<bool> showYesNoDialog(BuildContext context, String message,
    [String? title]) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title ?? defaultTitle),
      content: Text(message),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
          onPressed: () {
            Navigator.pop(context, true);
          },
          child: Text(Translations.instance!.trans('yes')),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
          onPressed: () {
            Navigator.pop(context, false);
          },
          child: Text(Translations.instance!.trans('no')),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool?> showYesNoCancelDialog(BuildContext context, String message,
    [String? title]) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title ?? defaultTitle),
      content: Text(message),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
          onPressed: () {
            Navigator.pop(context, true);
          },
          child: Text(Translations.instance!.trans('yes')),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
          onPressed: () {
            Navigator.pop(context, false);
          },
          child: Text(Translations.instance!.trans('no')),
        ),
      ],
    ),
  );
  return result;
}
