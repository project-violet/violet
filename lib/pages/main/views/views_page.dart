// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:violet/component/hitomi/artists.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/main/artist_collection/artist_list_page.dart';
import 'package:violet/settings/settings.dart';

class ViewsPage extends StatefulWidget {
  @override
  _ViewsPageState createState() => _ViewsPageState();
}

class _ViewsPageState extends State<ViewsPage> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    return Container(
      color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Card(
              elevation: 5,
              color:
                  Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
              child: SizedBox(
                width: width - 16,
                height: height - 16,
                child: Container(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
