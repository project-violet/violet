import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale.dart';
import 'package:violet/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class RecordViewPage extends StatelessWidget {
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
                child: Container(child: future(width)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget future(double width) {
    return FutureBuilder(
      future:
          User.getInstance().then((value) => value.getUserLog().then((value) {
                var overap = HashSet<String>();
                var rr = List<ArticleReadLog>();
                value.forEach((element) {
                  if (overap.contains(element.articleId())) return;
                  rr.add(element);
                  overap.add(element.articleId());
                });
                return rr;
              })),
      builder: (context, AsyncSnapshot<List<ArticleReadLog>> snapshot) {
        if (!snapshot.hasData) return Container();
        return ListView.builder(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.all(0),
          itemCount: snapshot.data.length,
          itemBuilder: (context, index) {
            var xx = snapshot.data[index];
            return SizedBox(
              height: 159,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: FutureBuilder(
                  future: QueryManager.query(
                      "SELECT * FROM HitomiColumnModel WHERE Id=${snapshot.data[index].articleId()}"),
                  builder: (context, AsyncSnapshot<QueryManager> snapshot) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        snapshot.hasData
                            ? ArticleListItemVerySimpleWidget(
                                queryResult: snapshot.data.results[0],
                                showDetail: true,
                                addBottomPadding: false,
                                width: (width - 16),
                                thumbnailTag: Uuid().v4(),
                              )
                            : Container(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          // crossAxisAlignment: CrossAxisAlignment,
                          children: <Widget>[
                            // Flexible(
                            //     child: Text(
                            //         ' ' +
                            //             unescape.convert(snapshot.hasData
                            //                 ? snapshot.data.results[0].title()
                            //                 : ''),
                            //         style: TextStyle(fontSize: 17),
                            //         overflow: TextOverflow.ellipsis)),
                            Flexible(
                              // child: Text(xx.datetimeStart().split(' ')[0]),
                              child: Text(''),
                            ),
                            Text(
                                xx.lastPage().toString() +
                                    ' ${Translations.of(context).trans('readpage')} ',
                                style: TextStyle(
                                  color: Settings.themeWhat
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                )),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
            // return ListTile() Text(snapshot.data[index].articleId().toString());
          },
        );
      },
    );
  }
}
