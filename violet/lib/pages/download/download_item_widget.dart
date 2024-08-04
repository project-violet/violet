// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/common/toast.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/download/download_item_menu.dart';
import 'package:violet/pages/download/download_routine.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/widgets/article_item/thumbnail.dart';

class DownloadListItem {
  bool addBottomPadding;
  bool showDetail;
  double width;

  DownloadListItem({
    required this.addBottomPadding,
    required this.showDetail,
    required this.width,
  });
}

typedef DownloadListItemCallback = void Function(DownloadListItem);
typedef DownloadListItemCallbackCallback = void Function(
    DownloadListItemCallback);

class DownloadItemWidget extends StatefulWidget {
  // final double width;
  final DownloadItemModel item;
  final DownloadListItem initialStyle;
  final bool download;
  final VoidCallback refeshCallback;

  const DownloadItemWidget({
    super.key,
    // this.width,
    required this.item,
    required this.initialStyle,
    required this.download,
    required this.refeshCallback,
  });

  @override
  State<DownloadItemWidget> createState() => DownloadItemWidgetState();
}

class DownloadItemWidgetState extends State<DownloadItemWidget>
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
  bool recoveryMode = false;
  late double thisWidth, thisHeight;
  late DownloadListItem style;
  bool isLastestRead = false;
  int latestReadPage = 0;
  bool disposed = false;

  bool downloaded = false;

  @override
  void initState() {
    super.initState();
    downloaded = widget.download;
    _styleCallback(widget.initialStyle);

    _checkLastRead();
    _downloadProcedure();
  }

  _checkLastRead() {
    User.getInstance().then((value) => value.getUserLog().then((value) async {
          final x = value.where((e) =>
              e.articleId() == widget.item.url() &&
              e.lastPage() != null &&
              e.lastPage()! > 1 &&
              DateTime.parse(e.datetimeStart())
                      .difference(DateTime.now())
                      .inDays <
                  31);
          if (x.isEmpty) return;
          _shouldReload = true;

          if (!disposed) {
            setState(() {
              isLastestRead = true;
              latestReadPage = x.first.lastPage()!;
            });
          }
        }));
  }

  _styleCallback(DownloadListItem item) {
    style = item;

    thisWidth = item.showDetail
        ? item.width - 16
        : item.width - (item.addBottomPadding ? 100 : 0);
    thisHeight = item.showDetail
        ? 130.0
        : item.addBottomPadding
            ? 500.0
            : item.width * 4 / 3;

    setState(() {});
  }

  _downloadProcedure() {
    Future.delayed(const Duration(milliseconds: 500)).then((value) async {
      if (once) return;
      once = true;

      final routine = DownloadRoutine(
          widget.item,
          () => setState(() {}),
          () => setState(() {
                _shouldReload = true;
              }));

      if (!await routine.checkValidState()) {
        return;
      }
      await routine.selectExtractor();

      if (!downloaded) {
        await routine.setToStop();
        return;
      }

      await routine.createTasks(
        progressCallback: (cur, max) async {
          setState(() {
            this.cur = cur;
            if (this.max < max) this.max = max;
          });
        },
      );

      if (await routine.checkNothingToDownload()) return;

      downloadTotalFileCount = routine.tasks!.length;

      await routine.extractFilePath();

      final timer =
          Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
        setState(() {
          if (downloadSec / 1024 < 500.0) {
            downloadSpeed = '${(downloadSec / 1024).toStringAsFixed(1)} KB/S';
          } else {
            downloadSpeed =
                '${(downloadSec / 1024 / 1024).toStringAsFixed(1)} MB/S';
          }
          downloadSec = 0;
        });
      });

      if (!recoveryMode) {
        await routine.appendDownloadTasks(
          completeCallback: () {
            downloadedFileCount++;
          },
          downloadCallback: (byte) {
            download += byte;
            downloadSec += byte;
          },
          errorCallback: (err) {
            downloadedFileCount++;
            errorFileCount++;
          },
        );

        // Wait for download complete
        while (downloadTotalFileCount != downloadedFileCount) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } else {
        downloadedFileCount = downloadTotalFileCount;
      }

      const maxRetryCount = 20;
      var retryCount = 0;

      // retry download when file is invalid or downloaded fail.
      while (retryCount < maxRetryCount) {
        var invalidFiles = await routine.checkDownloadFiles();

        if (invalidFiles.isEmpty || invalidFiles.length == errorFileCount) {
          break;
        }

        errorFileCount = 0;
        retryCount += 1;

        downloadedFileCount -= invalidFiles.length;

        await routine.retryInvalidDownloadFiles(
          invalidFiles,
          completeCallback: () {
            downloadedFileCount++;
          },
          downloadCallback: (byte) {
            download += byte;
            downloadSec += byte;
          },
          errorCallback: (err) {
            downloadedFileCount++;
            errorFileCount++;
          },
        );

        while (downloadTotalFileCount != downloadedFileCount) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      timer.cancel();

      await routine.setDownloadComplete();

      recoveryMode = false;

      if (!disposed) {
        showToast(
          icon: Icons.download,
          level: ToastLevel.check,
          message:
              '${widget.item.info()!.split('[')[1].split(']').first}${Translations.of(context).trans('download')} ${Translations.of(context).trans('complete')}',
        );
      }
    });
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return GestureDetector(
      child: SizedBox(
        width: thisWidth,
        height: thisHeight,
        child: AnimatedContainer(
          // alignment: FractionalOffset.center,
          curve: Curves.easeInOut,
          duration: const Duration(milliseconds: 300),
          // padding: EdgeInsets.all(pad),
          transform: Matrix4.identity()
            ..translate(thisWidth / 2, thisHeight / 2)
            ..scale(scale)
            ..translate(-thisWidth / 2, -thisHeight / 2),
          child: buildBody(),
        ),
      ),
      onLongPress: () async {
        setState(() {
          scale = 1.0;
        });

        var v = await showDialog(
          context: context,
          builder: (BuildContext context) => const DownloadImageMenu(),
        );

        if (v == -1) {
          // Delete
          if (widget.item.state() == 0) {
            for (var file in widget.item.rawFiles()) {
              if (await File(file).exists()) await File(file).delete();
            }
          }
          await widget.item.delete();
          (await Download.getInstance()).refresh();
          widget.refeshCallback();
        } else if (v == 2) {
          // Copy Url
          Clipboard.setData(ClipboardData(text: widget.item.url()));
          showToast(
            level: ToastLevel.check,
            message: 'URL Copied!',
          );
        } else if (v == 1) {
          _retry();
        } else if (v == 3) {
          _recovery();
        }
      },
      onTap: () async {
        if (widget.item.state() == 0 && widget.item.files() != null) {
          await (await User.getInstance())
              .insertUserLog(int.tryParse(widget.item.url()) ?? -1, 0);

          Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) {
                return Provider<ViewerPageProvider>.value(
                    value: ViewerPageProvider(
                      uris: widget.item.filesWithoutThumbnail(),
                      useFileSystem: true,
                      id: int.tryParse(widget.item.url()) ?? -1,
                      title: widget.item.info()!,
                    ),
                    child: const ViewerPage());
              },
            ),
          );
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
      onDoubleTap: () {
        setState(() {
          scale = 1.0;
        });
        if (int.tryParse(widget.item.url()) != null) {
          showArticleInfo(context, int.parse(widget.item.url()));
        }
      },
    );
  }

  _retry() {
    // Retry
    var copy = Map<String, dynamic>.from(widget.item.result);
    copy['State'] = 1;
    widget.item.result = copy;
    once = false;
    downloaded = true;
    _downloadProcedure();
    setState(() {
      _shouldReload = true;
    });
  }

  _recovery() {
    // recovery
    var copy = Map<String, dynamic>.from(widget.item.result);
    copy['State'] = 1;
    widget.item.result = copy;
    downloaded = true;
    once = false;
    recoveryMode = true;
    _downloadProcedure();
    setState(() {
      _shouldReload = true;
    });
  }

  retryWhenRequired() {
    if (widget.item.state() >= 6) _retry();
  }

  recovery() {
    if (widget.item.thumbnail() != null &&
        (widget.item.thumbnail()!.contains('e-hentai') ||
            widget.item.thumbnail()!.contains('exhentai'))) return;
    _recovery();
  }

  Widget buildBody() {
    return Container(
      // margin: const EdgeInsets.only(bottom: 6),
      margin: style.addBottomPadding
          ? style.showDetail
              ? const EdgeInsets.only(bottom: 6)
              : const EdgeInsets.only(bottom: 50)
          : EdgeInsets.zero,
      decoration: !Settings.themeFlat
          ? BoxDecoration(
              color: style.showDetail
                  ? Settings.themeWhat
                      ? Settings.themeBlack
                          ? Palette.blackThemeBackground
                          : Colors.grey.shade800
                      : Colors.white70
                  : Colors.grey.withOpacity(0.3),
              borderRadius: const BorderRadius.all(Radius.circular(5)),
              boxShadow: [
                BoxShadow(
                  color: Settings.themeWhat
                      ? Colors.grey.withOpacity(0.08)
                      : Colors.grey.withOpacity(0.4),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: const Offset(0, 3), // changes position of shadow
                ),
              ],
            )
          : null,
      color: !Settings.themeFlat || !style.showDetail
          ? null
          : Settings.themeWhat
              ? Colors.black26
              : Colors.white,
      child: style.showDetail
          ? Row(
              children: <Widget>[
                buildThumbnail(),
                Expanded(
                  child: buildDetail(),
                ),
              ],
            )
          : buildThumbnail(),
    );
  }

  Widget? _cachedThumbnail;
  bool _shouldReload = false;

  void thubmanilReload() {
    _shouldReload = true;
  }

  Widget buildThumbnail() {
    final height = MediaQuery.of(context).size.width / 3 * 4 / 3;
    final length = widget.item.filesWithoutThumbnail().length;

    if (_cachedThumbnail == null || _shouldReload) {
      _shouldReload = false;
      _cachedThumbnail = widget.item.state() == 0 &&
              widget.item.rawFiles().isNotEmpty &&
              File(widget.item.rawFiles().first).existsSync()
          ? _FileThumbnailWidget(
              showDetail: style.showDetail,
              thumbnailPath: widget.item.rawFiles().first,
              thumbnailTag: (widget.item.thumbnail() ?? '') +
                  widget.item.dateTime().toString(),
              usingRawImage: true,
              height: height,
            )
          : _ThumbnailWidget(
              showDetail: style.showDetail,
              id: int.tryParse(widget.item.url()) ?? -1,
              thumbnail: widget.item.thumbnail(),
              thumbnailTag: (widget.item.thumbnail() ?? '') +
                  widget.item.dateTime().toString(),
              thumbnailHeader: widget.item.thumbnailHeader(),
            );
    }

    return Visibility(
      visible: widget.item.thumbnail() != null,
      child: Container(
        foregroundDecoration: isLastestRead &&
                length > 0 &&
                length - latestReadPage <= 2 &&
                Settings.showArticleProgress
            ? BoxDecoration(
                color: Settings.themeWhat
                    ? Colors.grey.shade800
                    : Colors.grey.shade300,
                backgroundBlendMode: BlendMode.saturation,
              )
            : null,
        child: Stack(children: [
          _cachedThumbnail!,
          ReadProgressOverlayWidget(
            imageCount: widget.item.filesWithoutThumbnail().length,
            latestReadPage: latestReadPage,
            isLastestRead: isLastestRead,
            greyScale: false,
          ),
          PagesOverlayWidget(
            imageCount: widget.item.filesWithoutThumbnail().length,
            showDetail: style.showDetail,
          ),
        ]),
      ),
    );
  }

  Widget buildDetail() {
    var title = widget.item.url();

    if (widget.item.info() != null) {
      title = widget.item.info()!;
    }

    var state = 'None';
    var pp =
        '${Translations.instance!.trans('date')}: ${widget.item.dateTime()!}';

    var statecolor = !Settings.themeWhat ? Colors.black : Colors.white;
    var statebold = FontWeight.normal;

    switch (widget.item.state()) {
      case 0:
        state = Translations.instance!.trans('complete');
        break;
      case 1:
        state = Translations.instance!.trans('waitqueue');
        pp =
            '${Translations.instance!.trans('progress')}: ${Translations.instance!.trans('waitdownload')}';
        break;
      case 2:
        if (max == 0) {
          state = Translations.instance!.trans('extracting');
          pp =
              '${Translations.instance!.trans('progress')}: ${Translations.instance!.trans('count').replaceAll('%s', cur.toString())}';
        } else {
          state = '${Translations.instance!.trans('extracting')}[$cur/$max]';
          pp = '${Translations.instance!.trans('progress')}: ';
        }
        break;

      case 3:
        // state =
        //     '[$downloadedFileCount/$downloadTotalFileCount] ($downloadSpeed ${(download / 1024.0 / 1024.0).toStringAsFixed(1)} MB)';
        state = '[$downloadedFileCount/$downloadTotalFileCount]';
        pp = '${Translations.instance!.trans('progress')}: ';
        break;

      case 6:
        state = Translations.instance!.trans('stop');
        pp = '';
        statecolor = Colors.orange;
        // statebold = FontWeight.bold;
        break;
      case 7:
        state = Translations.instance!.trans('unknownerr');
        pp = '';
        statecolor = Colors.red;
        // statebold = FontWeight.bold;
        break;
      case 8:
        state = Translations.instance!.trans('urlnotsupport');
        pp = '';
        statecolor = Colors.redAccent;
        // statebold = FontWeight.bold;
        break;
      case 9:
        state = Translations.instance!.trans('tryagainlogin');
        pp = '';
        statecolor = Colors.redAccent;
        // statebold = FontWeight.bold;
        break;
      case 11:
        state = Translations.instance!.trans('nothingtodownload');
        pp = '';
        statecolor = Colors.orangeAccent;
        // statebold = FontWeight.bold;
        break;
    }

    return AnimatedContainer(
      margin: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      duration: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('${Translations.instance!.trans('dinfo')}: $title',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Container(
            height: 2,
          ),
          Text('${Translations.instance!.trans('state')}: $state',
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
                  style: const TextStyle(fontSize: 15))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(pp,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
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
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                      child: Container(),
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
  final String? thumbnail;
  final String? thumbnailHeader;
  final String? thumbnailTag;
  final bool showDetail;
  final int? id;

  const _ThumbnailWidget({
    required this.thumbnail,
    required this.thumbnailHeader,
    required this.thumbnailTag,
    required this.showDetail,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: showDetail ? 100 : double.infinity,
      child: thumbnail != null
          ? ClipRRect(
              borderRadius: showDetail
                  ? const BorderRadius.horizontal(left: Radius.circular(5.0))
                  : const BorderRadius.all(Radius.circular(5.0)),
              child: _thumbnailImage(),
            )
          : _getLoadingAnimation(),
    );
  }

  Widget _thumbnailImage() {
    if (id == null) {
      Map<String, String> headers = {};
      if (thumbnailHeader != null) {
        var hh = jsonDecode(thumbnailHeader!) as Map<String, dynamic>;
        for (var element in hh.entries) {
          headers[element.key] = element.value as String;
        }
      }
      return Hero(
        tag: thumbnailTag!,
        child: CachedNetworkImage(
          imageUrl: thumbnail!,
          fit: BoxFit.cover,
          httpHeaders: headers,
          imageBuilder: (context, imageProvider) => Container(
            decoration: BoxDecoration(
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
            child: Container(),
          ),
          placeholder: (b, c) {
            return _getLoadingAnimation();
          },
        ),
      );
    } else {
      return FutureBuilder(
        future: HitomiManager.getImageList(id.toString()).then((value) async {
          var header =
              await ScriptManager.runHitomiGetHeaderContent(id.toString());
          return Tuple2(value.item1[0], header);
        }),
        builder: (context,
            AsyncSnapshot<Tuple2<String, Map<String, String>>> snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return _getLoadingAnimation();
          }

          return Hero(
            tag: thumbnailTag!,
            child: CachedNetworkImage(
              imageUrl: snapshot.data!.item1,
              fit: BoxFit.cover,
              httpHeaders: snapshot.data!.item2,
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  image:
                      DecorationImage(image: imageProvider, fit: BoxFit.cover),
                ),
                child: Container(),
              ),
              placeholder: (b, c) {
                return _getLoadingAnimation();
              },
            ),
          );
        },
      );
    }
  }

  Widget _getLoadingAnimation() {
    if (!Settings.simpleItemWidgetLoadingIcon) {
      return const FlareActor(
        'assets/flare/Loading2.flr',
        alignment: Alignment.center,
        fit: BoxFit.fitHeight,
        animation: 'Alarm',
      );
    } else {
      return Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            color: Settings.majorColor.withAlpha(150),
          ),
        ),
      );
    }
  }
}

class _FileThumbnailWidget extends StatelessWidget {
  final String thumbnailPath;
  final String thumbnailTag;
  final bool showDetail;
  final bool usingRawImage;
  final double height;

  const _FileThumbnailWidget({
    required this.thumbnailPath,
    required this.thumbnailTag,
    required this.showDetail,
    this.usingRawImage = false,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: showDetail ? 100 : double.infinity,
      child: ClipRRect(
        borderRadius: showDetail
            ? const BorderRadius.horizontal(left: Radius.circular(5.0))
            : const BorderRadius.all(Radius.circular(5.0)),
        child: _thumbnailImage(),
      ),
    );
  }

  Widget _thumbnailImage() {
    return Hero(
      tag: thumbnailTag,
      child: ExtendedImage.file(
        File(thumbnailPath),
        fit: BoxFit.cover,
        cacheWidth: usingRawImage ? height.toInt() * 2 : null,
        loadStateChanged: (state) {
          if (state.extendedImageLoadState == LoadState.loading ||
              state.extendedImageLoadState == LoadState.failed) {
            return _getLoadingAnimation();
          }

          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                  image: state.imageProvider, fit: BoxFit.cover),
            ),
            child: Container(),
          );
        },
      ),
    );
  }

  Widget _getLoadingAnimation() {
    if (!Settings.simpleItemWidgetLoadingIcon) {
      return const FlareActor(
        'assets/flare/Loading2.flr',
        alignment: Alignment.center,
        fit: BoxFit.fitHeight,
        animation: 'Alarm',
      );
    } else {
      return Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            color: Settings.majorColor.withAlpha(150),
          ),
        ),
      );
    }
  }
}
