// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';

class ViewerRecordPanel extends StatefulWidget {
  final int articleId;

  const ViewerRecordPanel({Key? key, required this.articleId})
      : super(key: key);

  @override
  State<ViewerRecordPanel> createState() => _ViewerRecordPanelState();
}

class _ViewerRecordPanelState extends State<ViewerRecordPanel> {
  @override
  Widget build(BuildContext context) {
    var records = FutureBuilder(
      future: User.getInstance().then((value) => value.getUserLog().then(
          (value) => value
              .where((e) => e.articleId() == widget.articleId.toString())
              .toList())),
      builder: (context, AsyncSnapshot<List<ArticleReadLog>> snapshot) {
        if (!snapshot.hasData) return Container();
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
            return InkWell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        snapshot.data![index - 1].lastPage() == null
                            ? '??'
                            : '${snapshot.data![index - 1].lastPage()} Page',
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
                      snapshot.data![index - 1].datetimeStart().toString(),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
              onTap: () {
                Navigator.pop(context, snapshot.data![index - 1].lastPage());
              },
            );
          },
          itemCount: snapshot.data!.length + 1,
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
