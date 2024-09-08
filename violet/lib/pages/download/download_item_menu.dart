// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';

class DownloadImageMenu extends StatelessWidget {
  const DownloadImageMenu({super.key});

  Color getColor(int i) {
    return Settings.themeWhat ? Colors.grey.shade200 : Colors.grey.shade900;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context, 0);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(1)),
          boxShadow: [
            BoxShadow(
              color: Settings.themeWhat
                  ? Colors.black.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 1,
              offset: const Offset(0, 3), // changes position of shadow
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Card(
              color: Palette.themeColor,
              child: SizedBox(
                child: SizedBox(
                  width: 280,
                  height: (56 * 4 + 16).toDouble(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        // _typeItem(context, Icons.grid_on, 'srt0', 0),
                        _typeItem(context, MdiIcons.contentCopy, 'Copy URL', 2),
                        _typeItem(context, MdiIcons.refresh, 'Retry', 1),
                        _typeItem(context, MdiIcons.rotateLeft, 'Recovery', 3),
                        // _typeItem(context, MdiIcons.viewAgendaOutline, 'srt2', 2),
                        _typeItem(context, MdiIcons.trashCan, 'Delete', -1),
                        Expanded(
                          child: Container(),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeItem(
      BuildContext context, IconData icon, String text, int selection) {
    return ListTile(
      leading: Icon(icon, color: getColor(selection)),
      title: Text(text, //Translations.instance!.trans(text),
          style: TextStyle(color: getColor(selection))),
      onTap: () async {
        Navigator.pop(context, selection);
      },
    );
  }
}
