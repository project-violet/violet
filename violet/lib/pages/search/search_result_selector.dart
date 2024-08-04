// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/context/modal_bottom_sheet_context.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';

class SearchResultSelector extends StatelessWidget {
  const SearchResultSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
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
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Hero(
              tag: 'searchbar${ModalBottomSheetContext.getCount()}',
              child: Card(
                color: Settings.themeWhat
                    ? Palette.darkThemeBackground
                    : Palette.lightThemeBackground,
                child: SizedBox(
                  child: SizedBox(
                    width: width - 32,
                    height: height - 32,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
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
      ),
    );
  }
}
