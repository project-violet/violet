// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';

class ViewerRecordPanel extends StatefulWidget {
  final int articleId;

  const ViewerRecordPanel({super.key, required this.articleId});

  @override
  State<ViewerRecordPanel> createState() => _ViewerRecordPanelState();
}

class _ViewerRecordPanelState extends State<ViewerRecordPanel> {
  String durationToString(int param) {
    if (param < 60) return '${param}s';
    return '${param ~/ 60}m';
  }

  @override
  Widget build(BuildContext context) {
    var records = FutureBuilder(
      future: User.getInstance().then((value) => value.getUserLog().then(
          (value) => value
              .where((e) => e.articleId() == widget.articleId.toString())
              .toList())),
      builder: (context, AsyncSnapshot<List<ArticleReadLog>> snapshot) {
        if (!snapshot.hasData) return Container();
        final e = snapshot.data!;
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemExtent: 50.0,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(
                  'View Record',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            }

            final lastPage = e[index - 1].lastPage() == null
                ? '??'
                : '${e[index - 1].lastPage()} Page';

            var dt = e[index - 1].datetimeStart().toString();

            if (e[index - 1].datetimeEnd() != null) {
              final startDT = DateTime.tryParse(e[index - 1].datetimeStart());
              final endDT = DateTime.tryParse(e[index - 1].datetimeEnd()!);

              if (startDT != null && endDT != null) {
                final diff = endDT.difference(startDT).inSeconds;
                dt += ' (${durationToString(diff)})';
              }
            }

            return InkWell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        lastPage,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      dt,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
              onTap: () {
                Navigator.pop(context, e[index - 1].lastPage());
              },
            );
          },
          itemCount: e.length + 1,
        );
      },
    );

    if (Settings.enableViewerFunctionBackdropFilter) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6)),
            padding: EdgeInsets.only(bottom: Variables.bottomBarHeight),
            child: records,
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.black.withOpacity(0.8),
        padding: EdgeInsets.only(bottom: Variables.bottomBarHeight),
        child: records,
      );
    }
  }
}
