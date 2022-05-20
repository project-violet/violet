// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';

class DownloadAlignType extends StatefulWidget {
  const DownloadAlignType({Key key}) : super(key: key);

  @override
  State<DownloadAlignType> createState() => _DownloadAlignTypeState();
}

class _DownloadAlignTypeState extends State<DownloadAlignType> {
  Color getColor(int i) {
    return Settings.themeWhat
        ? Settings.downloadAlignType == i
            ? Colors.grey.shade200
            : Colors.grey.shade400
        : Settings.downloadAlignType == i
            ? Colors.grey.shade900
            : Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: 'downloadtype',
        child: Card(
          color: Settings.themeWhat
              ? Settings.themeBlack
                  ? const Color(0xFF141414)
                  : const Color(0xFF353535)
              : Colors.grey.shade100,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            width: 280,
            child: IntrinsicHeight(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: <Widget>[
                    _typeItem(context, MdiIcons.clipboardListOutline,
                        Translations.of(context).trans('alignnone'), 0),
                    _typeItem(context, MdiIcons.accountOutline,
                        Translations.of(context).trans('alignartist'), 1),
                    _typeItem(context, MdiIcons.accountMultipleOutline,
                        Translations.of(context).trans('aligngroup'), 2),
                    _typeItem(context, MdiIcons.fileOutline,
                        Translations.of(context).trans('alignpage'), 3),
                    _typeItem(context, MdiIcons.calendarClockOutline,
                        Translations.of(context).trans('alignrecentread'), 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeItem(
      BuildContext context, IconData icon, String text, int selection) {
    return ListTile(
      leading: Icon(icon, color: getColor(selection)),
      title: Text(text,
          softWrap: false, style: TextStyle(color: getColor(selection))),
      onTap: () async {
        await Settings.setDownloadAlignType(selection);

        if (!mounted) return;
        Navigator.pop(context);
      },
    );
  }
}
