// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/hitomi_provider.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

class ViewerThumbnail extends StatefulWidget {
  final int viewedPage;

  const ViewerThumbnail({Key? key, required this.viewedPage}) : super(key: key);

  @override
  State<ViewerThumbnail> createState() => _ViewerThumbnailState();
}

class _ViewerThumbnailState extends State<ViewerThumbnail> {
  late final ViewerPageProvider _pageInfo;
  List<GlobalKey> itemKeys = <GlobalKey>[];
  final ScrollController _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _pageInfo = Provider.of<ViewerPageProvider>(context);
    List.generate(_pageInfo.uris.length, (index) => index).forEach((element) {
      itemKeys.add(GlobalKey());
    });

    if (_pageInfo.useFileSystem) _jumpToViewedPage();
  }

  bool _alreadyJumped = false;

  _jumpToViewedPage() {
    if (_alreadyJumped) return;
    _alreadyJumped = true;
    Future.value(1).then((value) {
      var row = widget.viewedPage ~/ 3;
      if (row == 0) return;
      var firstItemHeight =
          (itemKeys[0].currentContext!.findRenderObject() as RenderBox)
              .size
              .height;
      _scrollController.jumpTo(
        row * (firstItemHeight + 8) - 100,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Settings.enableViewerFunctionBackdropFilter) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)),
            padding: EdgeInsets.only(bottom: Variables.bottomBarHeight),
            child: _buildThumbanilsList(),
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.black.withOpacity(0.8),
        padding: EdgeInsets.only(bottom: Variables.bottomBarHeight),
        child: _buildThumbanilsList(),
      );
    }
  }

  Widget _buildThumbanilsList() {
    if (_pageInfo.useFileSystem) {
      return _buildFileSystemThumbnailList();
    } else if (_pageInfo.useWeb) {
      // return _buildWebThumbnailList();
      throw UnimplementedError();
    } else if (_pageInfo.useProvider) {
      return _buildProviderThumbnailList();
    }
    throw UnimplementedError();
  }

  Widget _buildFileSystemThumbnailList() {
    final width = MediaQuery.of(context).size.width;

    return GridView.count(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 3 / 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: _pageInfo.uris
          .asMap()
          .map((i, e) => MapEntry(
              i,
              _buildTappableItem(
                i,
                Image.file(
                  File(e),
                  cacheWidth: width.toInt() ~/ 1.5,
                  filterQuality: FilterQuality.high,
                  fit: BoxFit.cover,
                ),
              )))
          .values
          .toList(),
    );
  }

  Widget _buildProviderThumbnailList() {
    if (ProviderManager.isExists(_pageInfo.id)) {
      return FutureBuilder(
        future: Future.value(1).then((value) async {
          VioletImageProvider prov = await ProviderManager.get(_pageInfo.id);

          if (!ProviderManager.isExists(_pageInfo.id * 1000000)) {
            if (ProviderManager.get(_pageInfo.id) is HitomiImageProvider) {
              prov = await ProviderManager.get(_pageInfo.id);
              ProviderManager.insert(_pageInfo.id * 1000000, prov);
            } else {
              try {
                var urls =
                    await HitomiManager.getImageList(_pageInfo.id.toString());
                if (urls.item1.isNotEmpty && urls.item2.isNotEmpty) {
                  prov = HitomiImageProvider(urls, _pageInfo.id.toString());
                  ProviderManager.insert(_pageInfo.id * 1000000, prov);
                }
              } catch (_) {}
            }
          } else {
            prov = await ProviderManager.get(_pageInfo.id * 1000000);
          }

          return Tuple2(
              await prov.getSmallImagesUrl(), await prov.getHeader(0));
        }),
        builder: (context,
            AsyncSnapshot<Tuple2<List<String>, Map<String, String>>> snapshot) {
          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          }
          Future.delayed(const Duration(milliseconds: 50))
              .then((value) => _jumpToViewedPage());
          return GridView.count(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 3,
            childAspectRatio: 3 / 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: snapshot.data!.item1
                .asMap()
                .map((i, e) => MapEntry(
                    i,
                    _buildTappableItem(
                      i,
                      CachedNetworkImage(
                        imageUrl: e,
                        httpHeaders: snapshot.data!.item2,
                        filterQuality: FilterQuality.high,
                        fit: BoxFit.cover,
                      ),
                    )))
                .values
                .toList(),
          );
        },
      );
    }
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Align(
            child: Text(
              'Thumbnail not found!',
              textAlign: TextAlign.center,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildTappableItem(int index, Widget image) {
    return SizedBox.expand(
      key: itemKeys[index],
      child: Stack(
        children: <Widget>[
          SizedBox.expand(child: image),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.only(bottom: 1),
              width: double.infinity,
              color: Colors.black.withOpacity(0.7),
              child: Text(
                '${index + 1} page',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context, index);
                },
                onLongPress: () async {
                  _showInfo(index);
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  Future _showInfo(i) async {
    try {
      var infoText = '';

      infoText += 'article: ${_pageInfo.id}\n';
      infoText += 'title: ${_pageInfo.title}\n\n';

      infoText +=
          'type: ${_pageInfo.useProvider ? 'provider' : _pageInfo.useFileSystem ? 'filesys' : _pageInfo.useWeb ? 'web' : 'none'}\n';

      if (_pageInfo.useProvider || _pageInfo.useFileSystem) {
        File? file;

        if (_pageInfo.useProvider) {
          final url = await _pageInfo.provider!.getImageUrl(i);
          final headers = await _pageInfo.provider!.getHeader(i);

          infoText += 'url: $url\n';
          infoText += 'header: ${json.encode(headers)}\n';

          file =
              await DefaultCacheManager().getSingleFile(url, headers: headers);
        } else if (_pageInfo.useFileSystem) {
          file = File(_pageInfo.uris[i]);
        }

        infoText += '\n';

        try {
          final image = await decodeImageFromList(file!.readAsBytesSync());

          infoText +=
              'size: ${toStringWithComma(image.width.toString())}x${toStringWithComma(image.height.toString())}\n';
        } catch (_) {}
        infoText +=
            'length: ${toStringWithComma((await file!.length() ~/ 1024).toString())}KB\n';
        infoText += 'filename: ${file.path}';
      }

      AlertDialog alert = AlertDialog(
        content: SelectableText(infoText),
      );
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return alert;
        },
      );
    } catch (e, st) {
      await Logger.error('[Viewer_thumbnails]\n'
          'E: $e\n'
          '$st');
    }
  }
}

RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
String Function(Match) mathFunc = (Match match) => '${match[1]},';
String toStringWithComma(String value) {
  return value.replaceAllMapped(reg, mathFunc);
}
