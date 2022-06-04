// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/pages/segment/card_panel.dart';

class UserManualPage extends StatefulWidget {
  const UserManualPage({Key? key}) : super(key: key);

  @override
  State<UserManualPage> createState() => _UserManualPageState();
}

class _UserManualPageState extends State<UserManualPage> {
  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: FutureBuilder(
        future: http
            .get(
                'https://raw.githubusercontent.com/project-violet/violet/dev/manual/ko.md')
            .then((value) => value.body),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return Markdown(
              physics: const BouncingScrollPhysics(),
              selectable: true,
              onTapLink: (text, href, title) async {
                if (await canLaunch(href!)) {
                  await launch(href);
                }
              },
              data: (snapshot.data as String).replaceAll('![](',
                  '![](https://github.com/project-violet/violet/raw/dev/manual/'));
        },
      ),
    );
  }
}
