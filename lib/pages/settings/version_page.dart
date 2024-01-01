// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/version/update_sync.dart';

class VersionViewPage extends StatelessWidget {
  const VersionViewPage({super.key});

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
                  child: Column(
                    children: <Widget>[
                      const Text(''),
                      const Text(
                        'Violet',
                        style: TextStyle(fontSize: 30),
                      ),
                      const Text(
                        '${UpdateSyncManager.majorVersion}.${UpdateSyncManager.minorVersion}.${UpdateSyncManager.patchVersion}',
                        style: TextStyle(fontSize: 20),
                      ),
                      const Text(''),
                      const Text('Project-Violet Android App'),
                      Text(
                        Translations.of(context).trans('infomessage'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10),
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
