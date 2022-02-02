// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/settings/settings.dart';

class RouteDialog extends StatefulWidget {
  RouteDialog();

  @override
  _RouteDialogState createState() => _RouteDialogState();
}

class _RouteDialogState extends State<RouteDialog> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return AlertDialog(
      contentPadding: EdgeInsets.all(16),
      content: Container(
        height: 80 * 5.0,
        width: width,
        child: ReorderableListView(
          onReorder: (oldIndex, newIndex) async {
            var old = Settings.searchRule[oldIndex];
            if (oldIndex > newIndex) {
              for (int i = oldIndex; i > newIndex; i--) {
                Settings.searchRule[i] = Settings.searchRule[i - 1];
              }
              Settings.searchRule[newIndex] = old;
            } else {
              for (int i = oldIndex; i < newIndex - 1; i++) {
                Settings.searchRule[i] = Settings.searchRule[i + 1];
              }
              Settings.searchRule[newIndex - 1] = old;
            }
            await (await SharedPreferences.getInstance())
                .setString('searchrule', Settings.searchRule.join('|'));
            setState(() {});
          },
          children: Settings.searchRule.map((e) {
            return ListTile(
              key: Key(e),
              title: Text(e),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
              leading: Image.network(
                {
                  'Hitomi':
                      'https://ltn.hitomi.la/apple-touch-icon-180x180.png',
                  'EHentai': 'https://e-hentai.org/favicon.ico',
                  'ExHentai': 'https://exhentai.org/favicon.ico',
                  'Hiyobi': 'https://hiyobi.me/favicon.ico',
                  'NHentai': 'https://nhentai.net/favicon.ico',
                  'Hisoki': 'https://hisoki.me/favicon.ico',
                }[e],
                height: 25,
                width: 25,
                fit: BoxFit.fill,
              ),
              trailing: Icon(Icons.reorder, color: Colors.grey, size: 24.0),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class ImageRouteDialog extends StatefulWidget {
  ImageRouteDialog();

  @override
  _ImageRouteDialogState createState() => _ImageRouteDialogState();
}

class _ImageRouteDialogState extends State<ImageRouteDialog> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return AlertDialog(
      contentPadding: EdgeInsets.all(16),
      content: Container(
        height: 80 * 5.0,
        width: width,
        child: ReorderableListView(
          onReorder: (oldIndex, newIndex) async {
            var old = Settings.routingRule[oldIndex];
            if (oldIndex > newIndex) {
              for (int i = oldIndex; i > newIndex; i--) {
                Settings.routingRule[i] = Settings.routingRule[i - 1];
              }
              Settings.routingRule[newIndex] = old;
            } else {
              for (int i = oldIndex; i < newIndex - 1; i++) {
                Settings.routingRule[i] = Settings.routingRule[i + 1];
              }
              Settings.routingRule[newIndex - 1] = old;
            }
            await (await SharedPreferences.getInstance())
                .setString('routingrule', Settings.routingRule.join('|'));
            setState(() {});
          },
          children: Settings.routingRule.map((e) {
            return ListTile(
              key: Key(e),
              title: Text(e),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
              leading: Image.network(
                {
                  'Hitomi':
                      'https://ltn.hitomi.la/apple-touch-icon-180x180.png',
                  'EHentai': 'https://e-hentai.org/favicon.ico',
                  'ExHentai': 'https://exhentai.org/favicon.ico',
                  'NHentai': 'https://nhentai.net/favicon.ico',
                  'Hisoki': 'https://hisoki.me/favicon.ico',
                }[e],
                height: 25,
                width: 25,
                fit: BoxFit.fill,
              ),
              trailing: Icon(Icons.reorder, color: Colors.grey, size: 24.0),
            );
          }).toList(),
        ),
      ),
    );
  }
}
