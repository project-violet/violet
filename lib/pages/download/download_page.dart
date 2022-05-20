// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_animated/auto_animated.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi_parser.dart';
import 'package:violet/component/hitomi/population.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/download/download_align_type.dart';
import 'package:violet/pages/download/download_features_menu.dart';
import 'package:violet/pages/download/download_item_widget.dart';
import 'package:violet/pages/download/download_view_type.dart';
import 'package:violet/pages/segment/filter_page.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/search_bar.dart';
import 'package:violet/widgets/toast.dart';

typedef StringCallback = Future Function(String);

class DownloadPageManager {
  static bool downloadPageLoaded = false;
  static StreamController<String> taskController;
}

// This page must remain alive until the app is closed.
class DownloadPage extends StatefulWidget {
  const DownloadPage({Key key}) : super(key: key);

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with AutomaticKeepAliveClientMixin<DownloadPage> {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scroll = ScrollController();
  List<DownloadItemModel> items = [];
  Map<int, DownloadItemModel> itemsMap = <int, DownloadItemModel>{};
  List<DownloadItemModel> filterResult = [];
  Map<int, QueryResult> queryResults = <int, QueryResult>{};
  final FilterController _filterController =
      FilterController(heroKey: 'downloadtype');
  ObjectKey _listKey = ObjectKey(const Uuid().v4());

  @override
  void initState() {
    super.initState();
    refresh();
    // DownloadPageManager.appendTask = appendTask;
    DownloadPageManager.taskController = StreamController<String>();
    DownloadPageManager.taskController.stream.listen((event) {
      appendTask(event);
    });
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void dispose() {
    DownloadPageManager.taskController.close();
    super.dispose();
  }

  void refresh() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      _getDownloadWidgetKey().forEach((key, value) {
        if (value.currentState != null) value.currentState.thubmanilReload();
      });
      items = await (await Download.getInstance()).getDownloadItems();
      itemsMap = <int, DownloadItemModel>{};
      filterResult = [];
      _listKey = ObjectKey(const Uuid().v4());
      queryResults = <int, QueryResult>{};
      await _autoRecoveryFileName();
      await _buildQueryResults();
      _applyFilter();
      setState(() {});
    });
  }

  Future<void> _autoRecoveryFileName() async {
    /// For ios, the app encryption name is changed when you update the app.
    /// Therefore, it is necessary to correct this.
    if (!Platform.isIOS) return;

    /// Replace
    /// /var/mobile/Containers/Data/Application/<old-app-code>/Documents
    /// to
    /// /var/mobile/Containers/Data/Application/<new-app-code>/Documents

    final newPath = (await getApplicationDocumentsDirectory()).path;

    for (var item in items) {
      if (item.files() == null) continue;

      if (item.files() != null &&
          item.files().toLowerCase().contains(newPath.toLowerCase())) continue;
      if (item.path() != null &&
          item.path().toLowerCase().contains(newPath.toLowerCase())) continue;

      final oldPath = ((jsonDecode(item.files()) as List<dynamic>)[0] as String)
          .split('/')
          .take(8)
          .join('/');

      Map<String, dynamic> result = Map<String, dynamic>.from(item.result);

      if (item.files() != null) {
        result['Files'] = item.files().replaceAll(oldPath, newPath);
      }
      if (item.path() != null) {
        result['Path'] = item.path().replaceAll(oldPath, newPath);
      }
      item.result = result;

      await item.update();
    }
  }

  Future<void> _buildQueryResults() async {
    var articles = <int>[];
    for (var item in items) {
      if (item.state() == 0 && int.tryParse(item.url()) != null) {
        articles.add(int.parse(item.url()));
        itemsMap[item.id()] = item;
      }
    }

    var queryRaw = 'SELECT * FROM HitomiColumnModel WHERE ';
    queryRaw += 'Id IN (${articles.map((e) => e).join(',')})';
    QueryManager.query(queryRaw).then((value) async {
      var qr = <int, QueryResult>{};
      for (var element in value.results) {
        qr[element.id()] = element;
      }

      var result = <QueryResult>[];
      Future.forEach<int>(articles, (element) async {
        if (qr[element] == null) {
          try {
            var headers = await ScriptManager.runHitomiGetHeaderContent(
                element.toString());
            var hh = await http.get(
              'https://ltn.hitomi.la/galleryblock/$element.html',
              headers: headers,
            );
            var article = await HitomiParser.parseGalleryBlock(hh.body);
            var meta = {
              'Id': element,
              'Title': article['Title'],
              'Artists': article['Artists'].join('|'),
            };
            result.add(QueryResult(result: meta));
            return;
          } catch (_) {}
        }
        result.add(qr[element]);
      });

      for (var element in result) {
        queryResults[element.id()] = element;
      }
    });
  }

  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double statusBarHeight = MediaQuery.of(context).padding.top;
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
                searchBar: Stack(
                  children: <Widget>[
                    _urlBar(),
                    _features(),
                    _align(),
                  ],
                ),
              ),
            ),
            // _cachedPanel,
            _panel(),
          ],
        ),
      ),
    );
  }

  Map<int, GlobalKey<DownloadItemWidgetState>> downloadItemWidgetKeys1 =
      <int, GlobalKey<DownloadItemWidgetState>>{};
  Map<int, GlobalKey<DownloadItemWidgetState>> downloadItemWidgetKeys2 =
      <int, GlobalKey<DownloadItemWidgetState>>{};
  Map<int, GlobalKey<DownloadItemWidgetState>> downloadItemWidgetKeys3 =
      <int, GlobalKey<DownloadItemWidgetState>>{};

  _getDownloadWidgetKey() {
    if (Settings.downloadResultType == 0 || Settings.downloadResultType == 1) {
      return downloadItemWidgetKeys1;
    }
    if (Settings.downloadResultType == 2 || Settings.downloadResultType == 3) {
      if (Settings.useTabletMode ||
          MediaQuery.of(context).orientation == Orientation.landscape) {
        return downloadItemWidgetKeys2;
      } else {
        return downloadItemWidgetKeys3;
      }
    }
  }

  double lastWindowWidth;
  Widget _panel() {
    var windowWidth = lastWindowWidth = MediaQuery.of(context).size.width;

    if (Settings.downloadResultType == 0 || Settings.downloadResultType == 1) {
      var mm = Settings.downloadResultType == 0 ? 3 : 2;
      return SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          sliver: SliverGrid(
            key: _listKey,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Settings.useTabletMode ? mm * 2 : mm,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3 / 4,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                var e = filterResult[filterResult.length - index - 1];
                if (!downloadItemWidgetKeys1
                    .containsKey(filterResult[index].id())) {
                  downloadItemWidgetKeys1[filterResult[index].id()] =
                      GlobalKey<DownloadItemWidgetState>();
                }
                return Align(
                  key: Key('dp${e.id()}${e.url()}'),
                  alignment: Alignment.bottomCenter,
                  child: DownloadItemWidget(
                    key: downloadItemWidgetKeys1[filterResult[index].id()],
                    initialStyle: DownloadListItem(
                      showDetail: false,
                      addBottomPadding: false,
                      width: (windowWidth - 4.0) / mm,
                    ),
                    item: e,
                    download: e.download,
                    refeshCallback: refresh,
                  ),
                );
              },
              childCount: filterResult.length,
            ),
          ));
    } else if (Settings.downloadResultType == 2 ||
        Settings.downloadResultType == 3) {
      if (Settings.useTabletMode ||
          MediaQuery.of(context).orientation == Orientation.landscape) {
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          sliver: LiveSliverGrid(
            key: _listKey,
            controller: _scrollController,
            showItemInterval: const Duration(milliseconds: 50),
            showItemDuration: const Duration(milliseconds: 150),
            visibleFraction: 0.001,
            itemCount: filterResult.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: (windowWidth / 2) / 130,
            ),
            itemBuilder: (context, index, animation) {
              var e = filterResult[filterResult.length - index - 1];
              if (!downloadItemWidgetKeys2
                  .containsKey(filterResult[index].id())) {
                downloadItemWidgetKeys2[filterResult[index].id()] =
                    GlobalKey<DownloadItemWidgetState>();
              }
              return Align(
                key: Key('dp${e.id()}${e.url()}'),
                alignment: Alignment.center,
                child: DownloadItemWidget(
                  key: downloadItemWidgetKeys2[filterResult[index].id()],
                  initialStyle: DownloadListItem(
                    showDetail: Settings.downloadResultType == 3,
                    addBottomPadding: true,
                    width: windowWidth - 4.0,
                  ),
                  item: e,
                  download: e.download,
                  refeshCallback: refresh,
                ),
              );
            },
          ),
        );
      } else {
        return SliverList(
          key: _listKey,
          delegate: SliverChildListDelegate(
            filterResult.reversed.map((e) {
              if (!downloadItemWidgetKeys3.containsKey(e.id())) {
                downloadItemWidgetKeys3[e.id()] =
                    GlobalKey<DownloadItemWidgetState>();
              }
              return Align(
                key: Key('dp${e.id()}${e.url()}'),
                alignment: Alignment.center,
                child: DownloadItemWidget(
                  key: downloadItemWidgetKeys3[e.id()],
                  initialStyle: DownloadListItem(
                    showDetail: Settings.downloadResultType == 3,
                    addBottomPadding: true,
                    width: windowWidth - 4.0,
                  ),
                  item: e,
                  download: e.download,
                  refeshCallback: refresh,
                ),
              );
            }).toList(),
          ),
        );
      }
    }

    return null;
  }

  Widget _urlBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 72 + 64.0 + 8, 0),
      child: SizedBox(
        height: 64,
        child: Card(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(4.0),
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
                        ? Settings.themeBlack
                            ? const Color(0xFF141414)
                            : Colors.grey.shade900.withOpacity(0.4)
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
                            contentPadding: const EdgeInsets.only(
                                left: 15, bottom: 11, top: 11, right: 15),
                            hintText: Translations.of(context).trans('addurl')),
                      ),
                      leading: const SizedBox(
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
                      if (!Settings.useInnerStorage &&
                          (await SharedPreferences.getInstance())
                                  .getBool('checkauthalready') ==
                              null) {
                        await (await SharedPreferences.getInstance())
                            .setBool('checkauthalready', true);
                        if (await Permission.storage.request() ==
                            PermissionStatus.denied) {
                          if (mounted) {
                            await showOkDialog(context,
                                'You cannot use downloader, if you not allow external storage permission.');
                          }
                          return;
                        }
                      }

                      if (!mounted) return;
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
                          contentPadding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 0),
                          title:
                              Text(Translations.of(context).trans('writeurl')),
                          content: TextField(
                            controller: text,
                            autofocus: true,
                          ),
                          actions: [yesButton, noButton],
                        ),
                      );
                      if (text.text.contains(',')) {
                        final ids = text.text.split(',').map((e) => e.trim());
                        if (ids
                            .any((element) => int.tryParse(element) == null)) {
                          if (mounted) {
                            await showOkDialog(
                                context, '콤마로 구분된 숫자만 입력해야 합니다!');
                          }
                          return;
                        }
                        if (dialog == true) {
                          for (var id in ids) {
                            await appendTask(id);
                          }
                        }
                      } else {
                        if (int.parse(text.text) == null) {
                          if (mounted) {
                            await showOkDialog(context, '숫자만 입력해야 합니다!');
                          }
                          return;
                        }
                        if (dialog == true) {
                          await appendTask(text.text);
                        }
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

  Widget _features() {
    double width = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.fromLTRB(width - 8 - 64 - 64 - 8, 8, 8, 0),
      child: SizedBox(
        height: 64,
        child: Hero(
          tag: 'features',
          child: Card(
            color: Settings.themeWhat
                ? Settings.themeBlack
                    ? const Color(0xFF141414)
                    : const Color(0xFF353535)
                : Colors.grey.shade100,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(4.0),
              ),
            ),
            elevation: !Settings.themeFlat ? 100 : 0,
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: InkWell(
              onTap: _featuresOnTap,
              child: SizedBox(
                height: 64,
                width: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: const <Widget>[
                    Icon(
                      MdiIcons.hammerWrench,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _featuresOnTap() async {
    Navigator.of(context)
        .push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget wi) {
        return FadeTransition(opacity: animation, child: wi);
      },
      pageBuilder: (_, __, ___) => const DownloadFeaturesMenu(),
      barrierColor: Colors.black12,
      barrierDismissible: true,
    ))
        .then((value) async {
      if (value == null) return;

      if (value == 0) {
        _getDownloadWidgetKey()
            .forEach((key, value) => value.currentState.retryWhenRequired());
      } else if (value == 1) {
        _getDownloadWidgetKey()
            .forEach((key, value) => value.currentState.recovery());
      } else if (value == 2) {
        Clipboard.setData(ClipboardData(
            text: filterResult.map((e) => int.tryParse(e.url())).join(', ')));
        FlutterToast(context).showToast(
          child: const ToastWrapper(
            isCheck: true,
            isWarning: false,
            msg: 'Ids Copied!',
          ),
          gravity: ToastGravity.BOTTOM,
          toastDuration: const Duration(seconds: 4),
        );
      }
    });
  }

  Widget _align() {
    double width = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.fromLTRB(width - 8 - 64, 8, 8, 0),
      child: SizedBox(
        height: 64,
        child: Hero(
          tag: 'downloadtype',
          child: Card(
            color: Settings.themeWhat
                ? Settings.themeBlack
                    ? const Color(0xFF141414)
                    : const Color(0xFF353535)
                : Colors.grey.shade100,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(4.0),
              ),
            ),
            elevation: !Settings.themeFlat ? 100 : 0,
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: InkWell(
              onTap: _alignOnTap,
              onDoubleTap: _alignDoubleTap,
              onLongPress: _alignLongPress,
              child: SizedBox(
                height: 64,
                width: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: const <Widget>[
                    Icon(
                      MdiIcons.formatListText,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _alignOnTap() async {
    var rtype = Settings.downloadResultType;
    Navigator.of(context)
        .push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget wi) {
        return FadeTransition(opacity: animation, child: wi);
      },
      pageBuilder: (_, __, ___) => const DownloadViewType(),
      barrierColor: Colors.black12,
      barrierDismissible: true,
    ))
        .then((value) async {
      if (rtype != Settings.downloadResultType) {
        var downloadWidgetKey = _getDownloadWidgetKey();
        downloadWidgetKey.forEach((key, value) =>
            downloadWidgetKey[key] = GlobalKey<DownloadItemWidgetState>());
        await Future.delayed(const Duration(milliseconds: 50), () {
          setState(() {});
        });
      }
    });
  }

  Future<void> _alignDoubleTap() async {
    var rtype = Settings.downloadAlignType;
    Navigator.of(context)
        .push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget wi) {
        return FadeTransition(opacity: animation, child: wi);
      },
      pageBuilder: (_, __, ___) => const DownloadAlignType(),
      barrierColor: Colors.black12,
      barrierDismissible: true,
    ))
        .then((value) async {
      if (rtype != Settings.downloadAlignType) {
        _getDownloadWidgetKey().forEach((key, value) {
          if (value.currentState != null) value.currentState.thubmanilReload();
        });
        _applyFilter();
      }
    });
  }

  Future<void> _alignLongPress() async {
    PlatformNavigator.navigateFade(
      context,
      Provider<FilterController>.value(
        value: _filterController,
        child: FilterPage(
          queryResult: queryResults.entries.map((e) => e.value).toList(),
        ),
      ),
    ).then((value) {
      _getDownloadWidgetKey().forEach((key, value) {
        if (value.currentState != null) value.currentState.thubmanilReload();
      });
      _applyFilter();
    });
  }

  Future<void> _applyFilter() async {
    var downloading = <int>[];
    var result = <int>[];
    var isOr = _filterController.isOr;
    for (var element in itemsMap.entries) {
      // 1: Pending
      // 2: Extracting
      // 3: Downloading
      // 4: Post Processing
      if (1 <= element.value.state() && element.value.state() <= 4) {
        downloading.add(element.key);
        continue;
      }

      if (int.tryParse(element.value.url()) == null) continue;
      final qr = queryResults[int.parse(element.value.url())];
      if (qr == null) continue;

      // key := <group>:<name>
      var succ = !_filterController.isOr;
      _filterController.tagStates.forEach((key, value) {
        if (!value) return;

        // Check match just only one
        if (succ == isOr) return;

        // Get db column name from group
        var split = key.split('|');
        var dbColumn = prefix2Tag(split[0]);

        // There is no matched db column name
        if (qr.result[dbColumn] == null && !isOr) {
          succ = false;
          return;
        }

        // If Single Tag
        if (!isSingleTag(split[0])) {
          var tag = split[1];
          if (['female', 'male'].contains(split[0])) {
            tag = '${split[0]}:${split[1]}';
          }
          if ((qr.result[dbColumn] as String).contains('|$tag|') == isOr) {
            succ = isOr;
          }
        }

        // If Multitag
        else if ((qr.result[dbColumn] as String == split[1]) == isOr) {
          succ = isOr;
        }
      });
      if (succ) result.add(element.key);
    }

    if (_filterController.tagStates.isNotEmpty) {
      filterResult = result.map((e) => itemsMap[e]).toList();
    } else {
      filterResult = items.toList();
    }

    if (_filterController.isPopulationSort) {
      Population.sortByPopulationDownloadItem(filterResult);
    }

    if (Settings.downloadAlignType > 0) {
      final user = await User.getInstance();
      final userlog = await user.getUserLog();
      final articlereadlog = <int, DateTime>{};

      for (var element in userlog) {
        if (!articlereadlog.containsKey(int.tryParse(element.articleId()))) {
          articlereadlog[int.tryParse(element.articleId())] =
              DateTime.parse(element.datetimeStart());
        }
      }

      filterResult.sort((x, y) {
        if (int.tryParse(x.url()) == null) return 1;
        if (int.tryParse(y.url()) == null) return -1;

        var xx = int.tryParse(x.url());
        var yy = int.tryParse(y.url());

        if (Settings.downloadAlignType == 3) {
          return y
              .filesWithoutThumbnail()
              .length
              .compareTo(x.filesWithoutThumbnail().length);
        } else if (Settings.downloadAlignType == 2) {
          if (!queryResults.containsKey(xx)) return 1;
          if (!queryResults.containsKey(yy)) return -1;

          final a1 = queryResults[xx].groups();
          final a2 = queryResults[yy].groups();

          if (a1 == null || a1 == '' || a1 == '|N/A|') return 1;
          if (a2 == null || a2 == '' || a2 == '|N/A|') return -1;

          final aa1 =
              (a1 as String).split('|').firstWhere((element) => element != '');
          final aa2 =
              (a2 as String).split('|').firstWhere((element) => element != '');

          return aa1.compareTo(aa2);
        } else if (Settings.downloadAlignType == 1) {
          if (!queryResults.containsKey(xx)) return 1;
          if (!queryResults.containsKey(yy)) return -1;

          final a1 = queryResults[xx].artists();
          final a2 = queryResults[yy].artists();

          if (a1 == null || a1 == '' || a1 == '|N/A|') return 1;
          if (a2 == null || a2 == '' || a2 == '|N/A|') return -1;

          final aa1 =
              (a1 as String).split('|').firstWhere((element) => element != '');
          final aa2 =
              (a2 as String).split('|').firstWhere((element) => element != '');

          return aa1.compareTo(aa2);
        } else if (Settings.downloadAlignType == 4) {
          if (!articlereadlog.containsKey(xx)) return 1;
          if (!articlereadlog.containsKey(yy)) return -1;

          return articlereadlog[yy].compareTo(articlereadlog[xx]);
        }

        return 0;
      });
      filterResult = filterResult.reversed.toList();
    }

    if (_filterController.tagStates.isNotEmpty && downloading.isNotEmpty) {
      filterResult.addAll(downloading.map((e) => itemsMap[e]).toList());
    }

    setState(() {});
  }

  static String prefix2Tag(String prefix) {
    switch (prefix) {
      case 'artist':
        return 'Artists';
      case 'group':
        return 'Groups';
      case 'language':
        return 'Language';
      case 'character':
        return 'Characters';
      case 'series':
        return 'Series';
      case 'class':
        return 'Class';
      case 'type':
        return 'Type';
      case 'uploader':
        return 'Uploader';
      case 'tag':
      case 'female':
      case 'male':
        return 'Tags';
    }
    return '';
  }

  static bool isSingleTag(String prefix) {
    switch (prefix) {
      case 'language':
      case 'class':
      case 'type':
      case 'uploader':
        return true;
      case 'artist':
      case 'group':
      case 'character':
      case 'tag':
      case 'female':
      case 'male':
      case 'series':
        return false;
    }
    return null;
  }

  Future<void> appendTask(String url) async {
    var item = await (await Download.getInstance()).createNew(url);
    item.download = true;
    items.add(item);
    itemsMap[item.id()] = item;
    await _appendQueryResults(url);
    _applyFilter();
  }

  Future<void> _appendQueryResults(String url) async {
    if (int.tryParse(url) == null) return;

    var queryRaw = 'SELECT * FROM HitomiColumnModel WHERE ';
    queryRaw += 'Id = $url';

    var qm = await QueryManager.query(queryRaw);

    if (qm.results.isEmpty) return;

    queryResults[int.parse(url)] = qm.results.first;
  }
}
