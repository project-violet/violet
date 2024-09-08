// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/context/modal_bottom_sheet_context.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';

class SearchType extends StatelessWidget {
  const SearchType({super.key});

  Color getColor(SearchResultType type) {
    return Settings.themeWhat
        ? Settings.searchResultType == type
            ? Colors.grey.shade200
            : Colors.grey.shade400
        : Settings.searchResultType == type
            ? Colors.grey.shade900
            : Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: 'searchtype${ModalBottomSheetContext.getCount()}',
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
                        SearchResultType.threeGrid),
                    _typeItem(context, MdiIcons.gridLarge, 'srt1',
                        SearchResultType.twoGrid),
                    _typeItem(context, MdiIcons.viewAgendaOutline, 'srt2',
                        SearchResultType.bigLine),
                    _typeItem(context, MdiIcons.formatListText, 'srt3',
                        SearchResultType.detail),
                    _typeItem(context, MdiIcons.viewSplitVertical, 'srt4',
                        SearchResultType.ultra,
                        flip: true),
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
      SearchResultType selection,
      {bool flip = false}) {
    return ListTile(
      leading: Transform.scale(
          scaleX: flip ? -1 : 1, child: Icon(icon, color: getColor(selection))),
      title: Text(Translations.of(context).trans(text),
          softWrap: false, style: TextStyle(color: getColor(selection))),
      onTap: () async {
        await Settings.setSearchResultType(selection);
        Navigator.pop(context);
      },
    );
  }
}
