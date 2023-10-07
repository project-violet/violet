// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:flutter/material.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/version/update_sync.dart';

class VioletPage extends StatelessWidget {
  const VioletPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(1)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
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
                  ? Colors.black.withOpacity(0.9)
                  : Colors.white.withOpacity(0.9),
              elevation: 10,
              child: SizedBox(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  width: 250,
                  height: 190,
                  child: const Column(
                    children: <Widget>[
                      Text(''),
                      Text(
                        'Violet',
                        style: TextStyle(fontSize: 30),
                      ),
                      Text(
                        '${UpdateSyncManager.majorVersion}.${UpdateSyncManager.minorVersion}.${UpdateSyncManager.patchVersion}',
                        style: TextStyle(fontSize: 20),
                      ),
                      Text(''),
                      // Text('Project-Violet Android App'),
                      Text(
                        'Violet은 강력한 검색기능 및 분석기능을 통해 사용자에게 다양한 경험을 제공하는 뷰어입니다.'
                        ' Violet이 제공하는 편리하고도 강력한 기능들을 체험해보세요!',
                        // Translations.of(context).trans('infomessage'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
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
