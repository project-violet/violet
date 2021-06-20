// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/download/download_item_widget.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/search_bar.dart';

typedef StringCallback = Future Function(String);

class DownloadPageManager {
  static bool downloadPageLoaded = false;
  static StringCallback appendTask;
}

// This page must remain alive until the app is closed.
class DownloadPage extends StatefulWidget {
  @override
  _DownloadPageState createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with AutomaticKeepAliveClientMixin<DownloadPage> {
  @override
  bool get wantKeepAlive => true;

  ScrollController _scroll = ScrollController();
  List<DownloadItemModel> items = [];

  @override
  void initState() {
    super.initState();
    refresh();
    DownloadPageManager.appendTask = appendTask;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void refresh() {
    Future.delayed(Duration(milliseconds: 500), () async {
      items = await (await Download.getInstance()).getDownloadItems();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    var windowWidth = MediaQuery.of(context).size.width;
    DownloadPageManager.downloadPageLoaded = true;

    return Container(
      padding: EdgeInsets.only(top: statusBarHeight),
      child: GestureDetector(
        child: CustomScrollView(
          // key: key,
          // cacheExtent: height * 100,
          controller: _scroll,
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverPersistentHeader(
              floating: true,
              delegate: AnimatedOpacitySliver(
                minExtent: 64 + 12.0,
                maxExtent: 64.0 + 12,
                searchBar: Stack(
                  children: <Widget>[
                    _urlBar(),
                    // _align(),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                items.reversed.map((e) {
                  // print(e.url());
                  return Align(
                    key: Key('dp' + e.id().toString() + e.url()),
                    alignment: Alignment.center,
                    child: DownloadItemWidget(
                      width: windowWidth - 4.0,
                      item: e,
                      download: e.download,
                      refeshCallback: refresh,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _urlBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: SizedBox(
        height: 64,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(8.0),
            ),
          ),
          elevation: !Settings.themeFlat ? 100 : 0,
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  Material(
                    color: Settings.themeWhat
                        ? Colors.grey.shade900.withOpacity(0.4)
                        : Colors.grey.shade200.withOpacity(0.4),
                    child: ListTile(
                      title: TextFormField(
                        cursorColor: Colors.black,
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.only(
                                left: 15, bottom: 11, top: 11, right: 15),
                            hintText: Translations.of(context).trans('addurl')),
                      ),
                      leading: SizedBox(
                        width: 25,
                        height: 25,
                        child: Icon(MdiIcons.instagram),
                      ),
                    ),
                  )
                ],
              ),
              Positioned(
                left: 0.0,
                top: 0.0,
                bottom: 0.0,
                right: 0.0,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () async {
                      if ((await SharedPreferences.getInstance())
                              .getBool('checkauthalready') ==
                          null) {
                        await (await SharedPreferences.getInstance())
                            .setBool('checkauthalready', true);
                        if (await Permission.storage.request() ==
                            PermissionStatus.denied) {
                          await Dialogs.okDialog(context,
                              "You cannot use downloader, if you not allow external storage permission.");
                          return;
                        }
                      }
                      Widget yesButton = TextButton(
                        style:
                            TextButton.styleFrom(primary: Settings.majorColor),
                        child: Text(Translations.of(context).trans('ok')),
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                      );
                      Widget noButton = TextButton(
                        style:
                            TextButton.styleFrom(primary: Settings.majorColor),
                        child: Text(Translations.of(context).trans('cancel')),
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                      );
                      TextEditingController text = TextEditingController();
                      var dialog = await showDialog(
                        useRootNavigator: false,
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                          title:
                              Text(Translations.of(context).trans('writeurl')),
                          content: TextField(
                            controller: text,
                            autofocus: true,
                          ),
                          actions: [yesButton, noButton],
                        ),
                      );
                      if (dialog == true) {
                        await appendTask(text.text);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> appendTask(String url) async {
    var item = await (await Download.getInstance()).createNew(url);
    item.download = true;
    setState(() {
      items.add(item);
      // items.insert(0, item);
      // key = ObjectKey(Uuid().v4());
    });
  }
}
