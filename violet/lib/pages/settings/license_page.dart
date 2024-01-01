// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:violet/pages/settings/libviolet_page.dart';
import 'package:violet/settings/settings.dart';

class VioletLicensePage extends StatelessWidget {
  const VioletLicensePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Settings.majorColor,
        title: const Text('LICENSES'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListTile(
              title: const Text('Libviolet License'),
              trailing: const Icon(Icons.keyboard_arrow_right),
              onTap: () async {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => const LibvioletPage(),
                  ),
                );
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
              title: const Text('Flutter & App License'),
              trailing: const Icon(Icons.keyboard_arrow_right),
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => LicensePage(
                      applicationName: 'Project Violet\n',
                      applicationIcon: Image.asset(
                        'assets/images/logo.png',
                        width: 100,
                        height: 100,
                      ),
                      applicationLegalese: 'Thank you for using my app!',
                    ),
                  ),
                );
              },
            ),
            Container(
              height: 50,
            ),
            Text(
              'This program was created using open sources.',
              style: TextStyle(
                color: Settings.themeWhat ? Colors.white : Colors.black87,
                fontSize: 12.0,
                // fontFamily: "Calibre-Semibold",
                letterSpacing: 1.0,
              ),
            ),
            Container(
              height: 50,
            ),
            Wrap(children: [
              SvgPicture.network(
                'https://github.com/project-violet/violet/releases/download/logos/flutter.svg',
                width: 50,
                height: 30,
              ),
              Container(
                width: 8,
              ),
              SvgPicture.network(
                'https://github.com/project-violet/violet/releases/download/logos/dart.svg',
                width: 30,
                height: 30,
              ),
              Container(
                width: 8,
              ),
              SvgPicture.network(
                'https://upload.wikimedia.org/wikipedia/commons/c/c3/Python-logo-notext.svg',
                width: 30,
                height: 30,
              ),
              Container(
                width: 8,
              ),
              Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d5/Rust_programming_language_black_logo.svg/800px-Rust_programming_language_black_logo.svg.png',
                width: 30,
                height: 30,
              ),
              Container(
                width: 8,
              ),
              Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/b/b5/Kotlin-logo.png',
                width: 30,
                height: 30,
              ),
              Container(
                width: 8,
              ),
              Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/b/b5/Kotlin-logo.png',
                width: 30,
                height: 30,
              ),
            ]),
            // Container(
            //   width: double.infinity,
            //   height: 0.5,
            //   color: Settings.themeWhat
            //       ? Colors.grey.shade600
            //       : Colors.grey.shade400,
            // ),
            // ListTile(
            //   title: Text('libViolet License'),
            //   trailing: Icon(Icons.open_in_new),
            //   onTap: () async {
            //     const url =
            //         'https://github.com/ytdl-org/youtube-dl/blob/master/LICENSE';
            //     if (await canLaunch(url)) {
            //       await launch(url);
            //     }
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}
