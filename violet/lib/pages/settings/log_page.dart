// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/log/log.dart';
import 'package:violet/other/dialogs.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final mediaQuery = MediaQuery.of(context);

    var errors = Logger.events.reversed.map((e) => e.copy()).toList();

    // Merge Simple Errors
    for (var i = 0; i < errors.length; i++) {
      if (errors[i].detail != null ||
          !(errors[i].message.startsWith('GET:') ||
              errors[i].message.startsWith('GETS:'))) continue;
      for (var j = i + 1; j < errors.length; j++) {
        if (errors[i].title != errors[j].title ||
            !(errors[j].message.startsWith('GET:') ||
                errors[j].message.startsWith('GETS:'))) break;
        if (errors[j].message.length < 200) {
          errors[i].message += '\n${errors[j].message}';
          errors.removeAt(j--);
        }
      }
    }

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(
            top: statusBarHeight + 16, bottom: mediaQuery.padding.bottom),
        child: Column(
          children: [
            const Text(
              'Log Record',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Container(
              height: 16,
            ),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(8),
                itemBuilder: (c, i) {
                  final ii = errors[i];

                  final icon = Icon(ii.isError == false && ii.isWarning == false
                      ? Icons.check
                      : ii.isWarning
                          ? Icons.warning
                          : Icons.cancel);

                  final title = Text(
                    ii.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  );

                  final defailButton = Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: 18.0,
                        width: 18.0,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.keyboard_arrow_right,
                            size: 24,
                          ),
                          onPressed: () async {
                            await showOkDialog(context, ii.detail!, '상세정보');
                          },
                        ),
                      ),
                    ),
                  );

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      color: ii.isError == false && ii.isWarning == false
                          ? Colors.greenAccent.withOpacity(0.8)
                          : ii.isWarning
                              ? Colors.orangeAccent.withOpacity(0.8)
                              : Colors.redAccent.withOpacity(0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            icon,
                            const SizedBox(
                              width: 12.0,
                            ),
                            title,
                            if (ii.detail != null) defailButton,
                          ],
                        ),
                        Container(height: 4),
                        Text(ii.message),
                      ],
                    ),
                  );
                },
                itemCount: errors.length,
                separatorBuilder: (context, index) {
                  return Container(
                    height: 8,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // ),
    );
  }
}
