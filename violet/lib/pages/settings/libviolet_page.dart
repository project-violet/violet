// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/settings/settings.dart';

class LibvioletPage extends StatelessWidget {
  const LibvioletPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Settings.majorColor,
        title: const Text('LIBVIOLET'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ExpandableNotifier(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ScrollOnExpand(
                  child: ExpandablePanel(
                    theme: ExpandableThemeData(
                        iconColor:
                            Settings.themeWhat ? Colors.white : Colors.grey,
                        animationDuration: const Duration(milliseconds: 500)),
                    header: const Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                      child: Text('What is libviolet?'),
                    ),
                    expanded: const Padding(
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
                    collapsed: Container(),
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
              title: const Text('openssl'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final url = Uri.parse('https://github.com/sfackler/rust-openssl');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
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
              title: const Text('futures-rs'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final url = Uri.parse('https://github.com/rust-lang/futures-rs');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
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
              title: const Text('hyper-native-tls'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final url = Uri.parse('https://github.com/sfackler/hyper-native-tls');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
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
              title: const Text('reqwest'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final url = Uri.parse('https://github.com/seanmonstar/reqwest');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
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
              title: const Text('tokio'),
              subtitle: const Text('MIT License'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final url = Uri.parse('https://github.com/tokio-rs/tokio');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
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
              title: const Text('serde'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final url = Uri.parse('https://github.com/serde-rs/serde');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
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
              title: const Text('serde-json'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final url = Uri.parse('https://github.com/serde-rs/json');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
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
              title: const Text('concurrent-queue'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final url = Uri.parse('https://github.com/stjepang/concurrent-queue');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
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
              title: const Text('lazy-static'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final url = Uri.parse('https://github.com/rust-lang-nursery/lazy-static.rs');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
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
              title: const Text('http'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final url = Uri.parse('https://github.com/hyperium/http');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
