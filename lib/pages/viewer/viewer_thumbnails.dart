// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/hitomi_provider.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/variables.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

class ViewerThumbnail extends StatefulWidget {
  final int viewedPage;

  ViewerThumbnail({this.viewedPage});

  @override
  _ViewerThumbnailState createState() => _ViewerThumbnailState();
}

class _ViewerThumbnailState extends State<ViewerThumbnail> {
  ViewerPageProvider _pageInfo;
  List<GlobalKey> itemKeys = <GlobalKey>[];
  ScrollController _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _pageInfo = Provider.of<ViewerPageProvider>(context);
    List.generate(_pageInfo.uris.length, (index) => index).forEach((element) {
      itemKeys.add(GlobalKey());
    });

    _jumpToViewedPage();
  }

  bool _alreadyJumped = false;

  _jumpToViewedPage() {
    if (_alreadyJumped) return;
    _alreadyJumped = true;
    Future.value(1).then((value) {
      var row = widget.viewedPage ~/ 3;
      if (row == 0) return;
      _scrollController.jumpTo(
        row *
                ((itemKeys[0].currentContext.findRenderObject() as RenderBox)
                        .size
                        .height +
                    8) -
            100,
        // duration: _kDuration,
        // curve: _kCurve
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
  }

  Widget _buildFileSystemThumbnailList() {
    final width = MediaQuery.of(context).size.width;

    return GridView.count(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
      controller: _scrollController,
      physics: BouncingScrollPhysics(),
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
                  cacheWidth: width.toInt() ~/ 2,
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
                if (urls.item1.length != 0 && urls.item2.length != 0) {
                  prov = HitomiImageProvider(urls, _pageInfo.id.toString());
                  ProviderManager.insert(_pageInfo.id * 1000000, prov);
                }
              } catch (e) {}
            }
          } else
            prov = await ProviderManager.get(_pageInfo.id * 1000000);

          return [await prov.getSmallImagesUrl(), await prov.getHeader(0)];
        }),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Container(child: CircularProgressIndicator());
          Future.delayed(Duration(milliseconds: 150))
              .then((value) => _jumpToViewedPage());
          return GridView.count(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
            controller: _scrollController,
            physics: BouncingScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 3,
            childAspectRatio: 3 / 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: (snapshot.data[0] as List<String>)
                .asMap()
                .map((i, e) => MapEntry(
                    i,
                    _buildTappableItem(
                      i,
                      CachedNetworkImage(
                        imageUrl: e,
                        httpHeaders: snapshot.data[1] as Map<String, String>,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
          // alignment: Alignment.center,
          child: Align(
            // alignment: Alignment.center,
            child: Text(
              'Thumbnail not found!',
              textAlign: TextAlign.center,
            ),
          ),
          width: 100,
          height: 100,
        )
      ],
    );
  }

  Widget _buildTappableItem(int index, Widget image) {
    return Container(
      key: itemKeys[index],
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: <Widget>[
          Container(
            width: double.infinity,
            height: double.infinity,
            child: image,
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: EdgeInsets.only(bottom: 1),
              width: double.infinity,
              color: Colors.black.withOpacity(0.7),
              child: Text(
                '${index + 1} page',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: Colors.white),
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
              ),
            ),
          )
        ],
      ),
    );
  }
}
