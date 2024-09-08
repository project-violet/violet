// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';

class DownloadViewType extends StatelessWidget {
  const DownloadViewType({super.key});

  Color getColor(DownloadResultType type) {
    return Settings.themeWhat
        ? Settings.downloadResultType == type
            ? Colors.grey.shade200
            : Colors.grey.shade400
        : Settings.downloadResultType == type
            ? Colors.grey.shade900
            : Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: 'downloadtype',
        child: Card(
          color: Palette.themeColor,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            width: 280,
            child: IntrinsicHeight(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: <Widget>[
                    _typeItem(context, Icons.grid_on, 'srt0',
                        DownloadResultType.threeGrid),
                    _typeItem(context, MdiIcons.gridLarge, 'srt1',
                        DownloadResultType.twoGrid),
                    _typeItem(context, MdiIcons.viewAgendaOutline, 'srt2',
                        DownloadResultType.bigLine),
                    _typeItem(context, MdiIcons.formatListText, 'srt3',
                        DownloadResultType.detail),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeItem(BuildContext context, IconData icon, String text,
      DownloadResultType selection) {
    return ListTile(
      leading: Icon(icon, color: getColor(selection)),
      title: Text(Translations.instance!.trans(text),
          softWrap: false, style: TextStyle(color: getColor(selection))),
      onTap: () async {
        await Settings.setDownloadResultType(selection);

        if (!context.mounted) return;
        Navigator.pop(context);
      },
    );
  }
}
