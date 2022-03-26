// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';

class DownloadAlignType extends StatelessWidget {
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
        tag: "downloadtype",
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
                physics: NeverScrollableScrollPhysics(),
                child: Column(
                  children: <Widget>[
                    _typeItem(
                        context, MdiIcons.clipboardListOutline, '일반 정렬', 0),
                    _typeItem(context, MdiIcons.accountOutline, '작가순으로 정렬', 1),
                    _typeItem(context, MdiIcons.accountMultipleOutline,
                        '그룹순으로 정렬', 2),
                    _typeItem(context, MdiIcons.fileOutline, '페이지순으로 정렬', 3),
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
        Navigator.pop(context);
      },
    );
  }
}
