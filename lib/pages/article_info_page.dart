// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:violet/database.dart';
import 'package:violet/settings.dart';

class ArticleInfoPage extends StatelessWidget {
  final QueryResult queryResult;
  final String thumbnail;
  final String heroKey;
  final Map<String, String> headers;

  ArticleInfoPage(
      {this.queryResult, this.heroKey, this.headers, this.thumbnail});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(1)),
        boxShadow: [
          BoxShadow(
            color: Settings.themeWhat
                ? Colors.black.withOpacity(0.4)
                : Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 1,
            offset: Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Hero(
            transitionOnUserGestures: true,
            tag: "articlecontainer" + queryResult.id().toString(),
            child: Card(
              color:
                  Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
              child: SizedBox(
                child: SizedBox(
                  width: width - 32,
                  height: height - 32,
                  child: Padding(
                    padding: EdgeInsets.all(0),
                    child: Stack(
                      children: <Widget>[
                        CachedNetworkImage(
                              imageUrl: thumbnail,
                              fit: BoxFit.cover,
                              httpHeaders: headers,
                              // height: 200,
                              // width: 100,
                            ),
                        Column(
                          children: <Widget>[
                            
                            Expanded(
                              child: Text('asdf'),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
