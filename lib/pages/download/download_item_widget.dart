// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:violet/component/downloadable.dart';
import 'package:violet/component/downloadable.dart' as violetd;
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/download/download_item_menu.dart';
import 'package:violet/downloader/native_downloader.dart';
import 'package:violet/pages/download/gallery/gallery_item.dart';
import 'package:violet/pages/download/gallery/gallery_page.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/widgets/article_item/thumbnail_manager.dart';
import 'package:violet/widgets/toast.dart';

class DownloadItemWidget extends StatefulWidget {
  final double width;
  final DownloadItemModel item;
  bool download;
  final VoidCallback refeshCallback;

  DownloadItemWidget({
    this.width,
    this.item,
    this.download,
    this.refeshCallback,
  });

  @override
  _DownloadItemWidgetState createState() => _DownloadItemWidgetState();
}

class _DownloadItemWidgetState extends State<DownloadItemWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  double scale = 1.0;
  String fav = '';
  int cur = 0;
  int max = 0;

  double download = 0;
  double downloadSec = 0;
  int downloadTotalFileCount = 0;
  int downloadedFileCount = 0;
  int errorFileCount = 0;
  String downloadSpeed = ' KB/S';
  bool once = false;

  @override
  void initState() {
    super.initState();

    if (ExtractorManager.instance.existsExtractor(widget.item.url())) {
      var extractor = ExtractorManager.instance.getExtractor(widget.item.url());
      if (extractor != null) fav = extractor.fav();
    }

    _downloadProcedure();
  }

  _downloadProcedure() {
    Future.delayed(Duration(milliseconds: 500)).then((value) async {
      if (once) return;
      once = true;
      // var downloader = await BuiltinDownloader.getInstance();
      var downloader = await NativeDownloader.getInstance();

      var result = Map<String, dynamic>.from(widget.item.result);

      if (widget.item.state() != 1) {
        if (widget.item.state() == 2 || widget.item.state() == 3) {
          result['State'] = 6;
          widget.item.result = result;
          await widget.item.update();
          setState(() {});
          return;
        }
        return;
      }

      // Check valid url
      if (!ExtractorManager.instance.existsExtractor(widget.item.url())) {
        result['State'] = 8;
        widget.item.result = result;
        await widget.item.update();
        setState(() {});
        return;
      }

      // Choose Extractor
      var extractor = ExtractorManager.instance.getExtractor(widget.item.url());
      result['State'] = 2;
      result['Extractor'] = extractor.name();
      widget.item.result = result;
      await widget.item.update();
      setState(() {});

      if (!widget.download) {
        result['State'] = 6;
        widget.item.result = result;
        await widget.item.update();
        setState(() {});
        return;
      }

      // while (true) {
      //   while (!downloader.hasDownloadSlot())
      //     await Future.delayed(Duration(milliseconds: 500));
      //   if (await downloader.ensureDownload()) break;
      // }

      // Login
      if (extractor.loginRequire()) {
        if (!extractor.logined()) {
          if (!await extractor.tryLogin()) {
            result['State'] = 9;
            widget.item.result = result;
            await widget.item.update();
            setState(() {});
            return;
          }
        }
      }

      // Extractor
      List<violetd.DownloadTask> tasks;

      try {
        tasks = await extractor.createTask(
          widget.item.url(),
          GeneralDownloadProgress(
            simpleInfoCallback: (info) async {
              result['Info'] = info;
              widget.item.result = result;
              await widget.item.update();
              setState(() {});
            },
            thumbnailCallback: (url, header) async {
              result['Thumbnail'] = url;
              result['ThumbnailHeader'] = header;
              widget.item.result = result;
              await widget.item.update();
              setState(() {});
            },
            progressCallback: (cur, max) async {
              setState(() {
                this.cur = cur;
                if (this.max < max) this.max = max;
              });
            },
          ),
        );
      } catch (e) {
        result['State'] = 7;
        widget.item.result = result;
        await widget.item.update();
        setState(() {});
        return;
      }

      if (tasks == null || tasks.length == 0) {
        result['State'] = 11;
        widget.item.result = result;
        await widget.item.update();
        setState(() {});
        return;
      }

      // Files and Path
      var files = tasks
          .map((e) => join(Settings.downloadBasePath,
              e.format.formatting(extractor.defaultFormat())))
          .toList();
      result['Files'] = jsonEncode(files);
      // Extract Super Path
      var cp = dirname(files[0]).split('/');
      var vp = cp.length;
      for (int i = 1; i < files.length; i++) {
        var tp = dirname(files[i]).split('/');
        for (int i = 0; i < vp; i++) {
          if (cp[i] != tp[i]) {
            vp = i;
            break;
          }
        }
      }
      var pp = cp.take(vp).join('/');
      result['Path'] = pp;
      widget.item.result = result;
      await widget.item.update();

      // Download
      var _timer =
          new Timer.periodic(Duration(milliseconds: 100), (Timer timer) {
        setState(() {
          if (downloadSec / 1024 < 500.0)
            downloadSpeed = (downloadSec / 1024).toStringAsFixed(1) + " KB/S";
          else
            downloadSpeed =
                (downloadSec / 1024 / 1024).toStringAsFixed(1) + " MB/S";
          downloadSec = 0;
        });
      });
      // var downloader = FlutterDonwloadDonwloader.getInstance();
      await downloader.addTasks(tasks.map((e) {
        e.downloadPath = join(Settings.downloadBasePath,
            e.format.formatting(extractor.defaultFormat()));

        e.startCallback = () {};
        e.completeCallback = () {
          downloadedFileCount++;
        };

        e.sizeCallback = (byte) {};
        e.downloadCallback = (byte) {
          download += byte;
          downloadSec += byte;
        };

        e.errorCallback = (err) {
          downloadedFileCount++;
          errorFileCount++;
        };

        return e;
      }).toList());
      downloadTotalFileCount = tasks.length;
      result['State'] = 3;
      widget.item.result = result;
      await widget.item.update();
      setState(() {});

      // Wait for download complete
      while (downloadTotalFileCount != downloadedFileCount) {
        await Future.delayed(Duration(milliseconds: 500));
      }
      _timer.cancel();

      // await (await BuiltinDownloader.getInstance()).returnDownload();

      // Postprocess

      // Complete!
      result['State'] = 0;
      widget.item.result = result;
      await widget.item.update();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    double ww = widget.width - 16;
    double hh = 130.0;

    return GestureDetector(
      child: SizedBox(
        width: ww,
        height: hh,
        child: AnimatedContainer(
          // alignment: FractionalOffset.center,
          curve: Curves.easeInOut,
          duration: Duration(milliseconds: 300),
          // padding: EdgeInsets.all(pad),
          transform: Matrix4.identity()
            ..translate(ww / 2, hh / 2)
            ..scale(scale)
            ..translate(-ww / 2, -hh / 2),
          child: buildBody(),
        ),
      ),
      onLongPress: () async {
        setState(() {
          scale = 1.0;
        });

        var v = await showDialog(
          context: context,
          child: DownloadImageMenu(),
        );

        if (v == -1) {
          await widget.item.delete();
          widget.refeshCallback();
        } else if (v == 2) {
          Clipboard.setData(new ClipboardData(text: widget.item.url()));
          FlutterToast(context).showToast(
            child: ToastWrapper(
              isCheck: true,
              isWarning: false,
              msg: 'URL Copied!',
            ),
            gravity: ToastGravity.BOTTOM,
            toastDuration: Duration(seconds: 4),
          );
        } else if (v == 1) {
          var copy = Map<String, dynamic>.from(widget.item.result);
          copy['State'] = 1;
          widget.item.result = copy;
          once = false;
          widget.download = true;
          _downloadProcedure();
          setState(() {});
        }
      },
      onTap: () async {
        if (widget.item.state() == 0 && widget.item.files() != null) {
          if (['hitomi', 'ehentai', 'exhentai']
              .contains(widget.item.extractor())) {
            SystemChrome.setEnabledSystemUIOverlays([]);

            Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (context) {
                  return Provider<ViewerPageProvider>.value(
                      value: ViewerPageProvider(
                        uris: (jsonDecode(widget.item.files()) as List<dynamic>)
                            .map((e) => e as String)
                            .toList(),
                        useFileSystem: true,
                        id: widget.item.id(),
                      ),
                      child: ViewerPage());
                },
              ),
            );
          } else {
            var gi = GalleryItem.fromDonwloadItem(widget.item);

            if (gi.length != 0) {
              Navigator.of(context).push(PageRouteBuilder(
                transitionDuration: Duration(milliseconds: 500),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  var begin = Offset(0.0, 1.0);
                  var end = Offset.zero;
                  var curve = Curves.ease;

                  var tween = Tween(begin: begin, end: end)
                      .chain(CurveTween(curve: curve));

                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
                pageBuilder: (_, __, ___) =>
                    GalleryPage(item: gi, model: widget.item),
              ));
            }
          }
        }
      },
      onTapDown: (details) {
        setState(() {
          scale = 0.95;
        });
      },
      onTapUp: (details) {
        setState(() {
          scale = 1.0;
        });
      },
      onTapCancel: () {
        setState(() {
          scale = 1.0;
        });
      },
    );
  }

  Widget buildBody() {
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Settings.themeWhat ? Colors.grey.shade800 : Colors.white70,
        borderRadius: BorderRadius.all(Radius.circular(5)),
        boxShadow: [
          BoxShadow(
            color: Settings.themeWhat
                ? Colors.grey.withOpacity(0.08)
                : Colors.grey.withOpacity(0.4),
            spreadRadius: 5,
            blurRadius: 7,
            offset: Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          buildThumbnail(),
          Expanded(
            child: buildDetail(),
          ),
        ],
      ),
    );
  }

  Widget buildThumbnail() {
    return Visibility(
      visible: widget.item.thumbnail() != null,
      child: _ThumbnailWidget(
        thumbnail: widget.item.thumbnail(),
        thumbnailTag:
            (widget.item.thumbnail() == null ? '' : widget.item.thumbnail()) +
                widget.item.dateTime().toString(),
        thumbnailHeader: widget.item.thumbnailHeader(),
      ),
    );
  }

  Widget buildDetail() {
    var title = widget.item.url();

    if (widget.item.info() != null) {
      title = widget.item.info();
    }

    var state = 'None';
    var pp =
        '${Translations.instance.trans('date')}: ' + widget.item.dateTime();

    var statecolor = !Settings.themeWhat ? Colors.black : Colors.white;
    var statebold = FontWeight.normal;

    switch (widget.item.state()) {
      case 0:
        state = Translations.instance.trans('complete');
        break;
      case 1:
        state = Translations.instance.trans('waitqueue');
        pp = Translations.instance.trans('progress') +
            ': ' +
            Translations.instance.trans('waitdownload');
        break;
      case 2:
        if (max == 0) {
          state = Translations.instance.trans('extracting');
          pp = Translations.instance.trans('progress') +
              ': ' +
              Translations.instance
                  .trans('count')
                  .replaceAll('%s', cur.toString());
        } else {
          state = Translations.instance.trans('extracting') + '[$cur/$max]';
          pp = Translations.instance.trans('progress') + ': ';
        }
        break;

      case 3:
        // state =
        //     '[$downloadedFileCount/$downloadTotalFileCount] ($downloadSpeed ${(download / 1024.0 / 1024.0).toStringAsFixed(1)} MB)';
        state = '[$downloadedFileCount/$downloadTotalFileCount]';
        pp = Translations.instance.trans('progress') + ': ';
        break;

      case 6:
        state = Translations.instance.trans('stop');
        pp = '';
        statecolor = Colors.orange;
        // statebold = FontWeight.bold;
        break;
      case 7:
        state = Translations.instance.trans('unknownerr');
        pp = '';
        statecolor = Colors.red;
        // statebold = FontWeight.bold;
        break;
      case 8:
        state = Translations.instance.trans('urlnotsupport');
        pp = '';
        statecolor = Colors.redAccent;
        // statebold = FontWeight.bold;
        break;
      case 9:
        state = Translations.instance.trans('tryagainlogin');
        pp = '';
        statecolor = Colors.redAccent;
        // statebold = FontWeight.bold;
        break;
      case 11:
        state = Translations.instance.trans('nothingtodownload');
        pp = '';
        statecolor = Colors.orangeAccent;
        // statebold = FontWeight.bold;
        break;
    }

    return AnimatedContainer(
      margin: EdgeInsets.fromLTRB(8, 4, 4, 4),
      duration: Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(Translations.instance.trans('dinfo') + ': ' + title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Container(
            height: 2,
          ),
          Text(Translations.instance.trans('state') + ': ' + state,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15, color: statecolor, fontWeight: statebold)),
          Container(
            height: 2,
          ),
          widget.item.state() != 3
              ? Text(pp,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(pp,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15)),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: LinearProgressIndicator(
                          value: downloadedFileCount / downloadTotalFileCount,
                          minHeight: 18,
                        ),
                      ),
                    ),
                  ],
                ),
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(0, 0, 0, 4),
                      child: fav != '' && fav != null
                          ? CachedNetworkImage(
                              imageUrl: fav,
                              width: 25,
                              height: 25,
                              fadeInDuration: Duration(microseconds: 500),
                              fadeInCurve: Curves.easeIn)
                          : Container(),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailWidget extends StatelessWidget {
  final String thumbnail;
  final String thumbnailHeader;
  final String thumbnailTag;

  _ThumbnailWidget({
    this.thumbnail,
    this.thumbnailHeader,
    this.thumbnailTag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      child: thumbnail != null
          ? ClipRRect(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(5.0)),
              child: _thumbnailImage(),
            )
          : FlareActor(
              "assets/flare/Loading2.flr",
              alignment: Alignment.center,
              fit: BoxFit.fitHeight,
              animation: "Alarm",
            ),
    );
  }

  Widget _thumbnailImage() {
    Map<String, String> headers = {};
    if (thumbnailHeader != null) {
      var hh = jsonDecode(thumbnailHeader) as Map<String, dynamic>;
      hh.entries.forEach((element) {
        headers[element.key] = element.value as String;
      });
    }
    return Hero(
      tag: thumbnailTag,
      child: CachedNetworkImage(
        imageUrl: thumbnail,
        fit: BoxFit.cover,
        httpHeaders: headers,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
          child: Container(),
        ),
        placeholder: (b, c) {
          return FlareActor(
            "assets/flare/Loading2.flr",
            alignment: Alignment.center,
            fit: BoxFit.fitHeight,
            animation: "Alarm",
          );
        },
      ),
    );
  }
}
