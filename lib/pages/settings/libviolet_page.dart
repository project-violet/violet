// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'package:expandable/expandable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/settings/settings.dart';

class LibvioletPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Settings.majorColor,
        title: Text('LIBVIOLET'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ExpandableNotifier(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: ScrollOnExpand(
                  child: ExpandablePanel(
                    theme: ExpandableThemeData(
                        iconColor:
                            Settings.themeWhat ? Colors.white : Colors.grey,
                        animationDuration: const Duration(milliseconds: 500)),
                    header: Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                      child: Text('What is libviolet?'),
                    ),
                    expanded: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Column(
                        children: [
                          Text(
                              'Libviolet is a very fast download library implemented based on Rust. '
                              'This download library allows downloads up to the network maximum download speed.',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ListTile(
              title: Text('openssl'),
              trailing: Icon(Icons.open_in_new),
              onTap: () async {
                const url = 'https://github.com/sfackler/rust-openssl';
                if (await canLaunch(url)) {
                  await launch(url);
                }
              },
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ListTile(
              title: Text('futures-rs'),
              trailing: Icon(Icons.open_in_new),
              onTap: () async {
                const url = 'https://github.com/rust-lang/futures-rs';
                if (await canLaunch(url)) {
                  await launch(url);
                }
              },
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ListTile(
              title: Text('hyper-native-tls'),
              trailing: Icon(Icons.open_in_new),
              onTap: () async {
                const url = 'https://github.com/sfackler/hyper-native-tls';
                if (await canLaunch(url)) {
                  await launch(url);
                }
              },
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ListTile(
              title: Text('reqwest'),
              trailing: Icon(Icons.open_in_new),
              onTap: () async {
                const url = 'https://github.com/seanmonstar/reqwest';
                if (await canLaunch(url)) {
                  await launch(url);
                }
              },
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ListTile(
              title: Text('tokio'),
              subtitle: Text('MIT License'),
              trailing: Icon(Icons.open_in_new),
              onTap: () async {
                const url = 'https://github.com/tokio-rs/tokio';
                if (await canLaunch(url)) {
                  await launch(url);
                }
              },
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ListTile(
              title: Text('serde'),
              trailing: Icon(Icons.open_in_new),
              onTap: () async {
                const url = 'https://github.com/serde-rs/serde';
                if (await canLaunch(url)) {
                  await launch(url);
                }
              },
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ListTile(
              title: Text('serde-json'),
              trailing: Icon(Icons.open_in_new),
              onTap: () async {
                const url = 'https://github.com/serde-rs/json';
                if (await canLaunch(url)) {
                  await launch(url);
                }
              },
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ListTile(
              title: Text('concurrent-queue'),
              trailing: Icon(Icons.open_in_new),
              onTap: () async {
                const url = 'https://github.com/stjepang/concurrent-queue';
                if (await canLaunch(url)) {
                  await launch(url);
                }
              },
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ListTile(
              title: Text('lazy-static'),
              trailing: Icon(Icons.open_in_new),
              onTap: () async {
                const url =
                    'https://github.com/rust-lang-nursery/lazy-static.rs';
                if (await canLaunch(url)) {
                  await launch(url);
                }
              },
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ListTile(
              title: Text('http'),
              trailing: Icon(Icons.open_in_new),
              onTap: () async {
                const url = 'https://github.com/hyperium/http';
                if (await canLaunch(url)) {
                  await launch(url);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
