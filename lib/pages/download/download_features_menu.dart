// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';

class DownloadFeaturesMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: "features",
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
                        context, MdiIcons.refresh, 'Retry Stopped Item', 0),
                    _typeItem(context, MdiIcons.rotateLeft, 'All Recovery', 1),
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
      leading: Icon(
        icon,
        color: Settings.themeWhat ? Colors.grey.shade200 : Colors.grey.shade900,
      ),
      title: Text(text,
          softWrap: false,
          style: TextStyle(
            color: Settings.themeWhat
                ? Colors.grey.shade200
                : Colors.grey.shade900,
          )),
      onTap: () async {
        Navigator.pop(context, selection);
      },
    );
  }
}
