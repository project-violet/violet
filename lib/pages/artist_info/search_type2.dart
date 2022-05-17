// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';

class SearchType2 extends StatelessWidget {
  Color getColor(int i) {
    return Settings.themeWhat
        ? nowType == i
            ? Colors.grey.shade200
            : Colors.grey.shade400
        : nowType == i
            ? Colors.grey.shade900
            : Colors.grey.shade400;
  }

  final int nowType;
  const SearchType2({Key key, this.nowType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Hero(
            tag: 'searchtype2',
            child: Card(
              color: Settings.themeWhat
                  ? Settings.themeBlack
                      ? const Color(0xFF141414)
                      : const Color(0xFF353535)
                  : Colors.grey.shade100,
              child: SizedBox(
                child: SizedBox(
                  width: 280,
                  height: 240,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        ListTile(
                          leading: Icon(Icons.grid_on, color: getColor(0)),
                          title: Text(Translations.of(context).trans('srt0'),
                              style: TextStyle(color: getColor(0))),
                          onTap: () async {
                            Navigator.pop(context, 0);
                          },
                        ),
                        ListTile(
                          leading: Icon(MdiIcons.gridLarge, color: getColor(1)),
                          title: Text(Translations.of(context).trans('srt1'),
                              style: TextStyle(color: getColor(1))),
                          onTap: () async {
                            Navigator.pop(context, 1);
                          },
                        ),
                        ListTile(
                          leading: Icon(MdiIcons.viewAgendaOutline,
                              color: getColor(2)),
                          title: Text(
                            Translations.of(context).trans('srt2'),
                            style: TextStyle(color: getColor(2)),
                          ),
                          onTap: () async {
                            Navigator.pop(context, 2);
                          },
                        ),
                        ListTile(
                          leading:
                              Icon(MdiIcons.formatListText, color: getColor(3)),
                          title: Text(
                            Translations.of(context).trans('srt3'),
                            style: TextStyle(color: getColor(3)),
                          ),
                          onTap: () async {
                            Navigator.pop(context, 3);
                          },
                        ),
                        Expanded(
                          child: Container(),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
