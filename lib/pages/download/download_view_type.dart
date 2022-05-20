// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';

class DownloadViewType extends StatefulWidget {
  const DownloadViewType({Key key}) : super(key: key);

  @override
  State<DownloadViewType> createState() => _DownloadViewTypeState();
}

class _DownloadViewTypeState extends State<DownloadViewType> {
  Color getColor(int i) {
    return Settings.themeWhat
        ? Settings.downloadResultType == i
            ? Colors.grey.shade200
            : Colors.grey.shade400
        : Settings.downloadResultType == i
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
                    _typeItem(context, Icons.grid_on, 'srt0', 0),
                    _typeItem(context, MdiIcons.gridLarge, 'srt1', 1),
                    _typeItem(context, MdiIcons.viewAgendaOutline, 'srt2', 2),
                    _typeItem(context, MdiIcons.formatListText, 'srt3', 3),
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
      title: Text(Translations.of(context).trans(text),
          softWrap: false, style: TextStyle(color: getColor(selection))),
      onTap: () async {
        await Settings.setDownloadResultType(selection);

        if (!mounted) return;
        Navigator.pop(context);
      },
    );
  }
}
