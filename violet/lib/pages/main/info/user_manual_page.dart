// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/pages/main/faq/faq_page.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/settings/settings.dart';

class UserManualPage extends StatefulWidget {
  @override
  _UserManualPageState createState() => _UserManualPageState();
}

class _UserManualPageState extends State<UserManualPage> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;

    final mediaQuery = MediaQuery.of(context);

    return Container(
      color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
      child: Padding(
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            bottom: (mediaQuery.padding + mediaQuery.viewInsets).bottom),
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
                height: height -
                    16 -
                    (mediaQuery.padding + mediaQuery.viewInsets).bottom,
                child: FutureBuilder(
                  future: http
                      .get(
                          'https://raw.githubusercontent.com/project-violet/violet/dev/manual/ko.md')
                      .then((value) => value.body),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return Container();
                    return Markdown(
                        physics: BouncingScrollPhysics(),
                        selectable: true,
                        onTapLink: (text, href, title) async {
                          if (await canLaunch(href)) {
                            await launch(href);
                          }
                        },
                        data: (snapshot.data as String).replaceAll('![](',
                            '![](https://github.com/project-violet/violet/raw/dev/manual/'));
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
