// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/component/eh/eh_bookmark.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';

class ImportFromEHPage extends StatefulWidget {
  const ImportFromEHPage({Key? key}) : super(key: key);

  @override
  State<ImportFromEHPage> createState() => _ImportFromEHPageState();
}

class _ImportFromEHPageState extends State<ImportFromEHPage> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      await EHBookmark.process();

      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
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
              color: Settings.themeWhat
                  ? Palette.darkThemeBackground
                  : Palette.lightThemeBackground,
              elevation: 100,
              child: SizedBox(
                child: SizedBox(
                  width: 280,
                  height: (56 * 4 + 16).toDouble(),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(0, 8, 0, 8),
                    // child: Column(
                    //   mainAxisAlignment: MainAxisAlignment.center,
                    //   children: <Widget>[
                    //     CircularProgressIndicator(),
                    //     Expanded(
                    //       child: Container(child: Text('초기화 중...')),
                    //     )
                    //   ],
                    // ),
                    child: Stack(
                      children: [
                        Center(
                          child: CircularProgressIndicator(),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 33),
                            child: Text(
                              '가져오는 중',
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 15),
                            child: Text(
                              '잠시만 기다려주세요...',
                            ),
                          ),
                        ),
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
}
