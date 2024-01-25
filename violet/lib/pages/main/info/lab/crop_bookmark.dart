// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image/image.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/pages/article_info/preview_area.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/v_cached_network_image.dart';

class CropBookmarkPage extends StatefulWidget {
  const CropBookmarkPage({super.key});

  @override
  State<CropBookmarkPage> createState() => _CropBookmarkPageState();
}

class _CropBookmarkPageState extends State<CropBookmarkPage> {
  List<String>? imagsUrlForEvict;
  List<double>? _height;
  List<GlobalKey>? _keys;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: Bookmark.getInstance().then((value) => value.getCropImages()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container();
          }

          final imgs = snapshot.data!;

          _height ??= List<double>.filled(imgs.length, 0);
          imagsUrlForEvict = List<String>.filled(imgs.length, '');
          _keys = List<GlobalKey>.generate(imgs.length, (index) => GlobalKey());

          return MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            itemCount: imgs.length,
            cacheExtent: double.infinity,
            itemBuilder: (context, index) {
              final e = imgs[index];
              final area =
                  e.area().split(',').map((e) => double.parse(e)).toList();
              return buildItem(
                index,
                e.article(),
                e.page(),
                Rect.fromLTRB(
                  area[0],
                  area[1],
                  area[2],
                  area[3],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget buildItem(
    int index,
    int articleId,
    int page,
    Rect rect,
  ) {
    return FutureBuilder(
      future:
          Future.delayed(const Duration(milliseconds: 100)).then((value) async {
        VioletImageProvider provider;

        if (ProviderManager.isExists(articleId)) {
          provider = await ProviderManager.get(articleId);
        } else {
          final query =
              (await HentaiManager.idSearch(articleId.toString())).results;
          provider = await HentaiManager.getImageProvider(query[0]);
          await provider.init();
          ProviderManager.insert(query[0].id(), provider);
        }

        return Tuple2(
            imagsUrlForEvict![index] = await provider.getImageUrl(page),
            await provider.getHeader(page));
      }),
      builder: (context,
          AsyncSnapshot<Tuple2<String, Map<String, String>>> snapshot) {
        if (!snapshot.hasData) {
          return Column(
            children: [
              AspectRatio(
                aspectRatio: rect.width / rect.height,
                child: const Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              // ListTile(
              //   title: Text('$articleId (${page + 1} Page)'),
              // ),
            ],
          );
        }

        return Column(children: [
          CropImageWidget(
            articleId: articleId,
            url: snapshot.data!.item1,
            headers: snapshot.data!.item2,
            rect: rect,
          ),
        ]);
      },
    );
  }
}

class CropImageWidget extends StatefulWidget {
  final String url;
  final Map<String, String> headers;
  final int articleId;
  final Rect rect;

  const CropImageWidget({
    super.key,
    required this.url,
    required this.headers,
    required this.articleId,
    required this.rect,
  });

  @override
  State<CropImageWidget> createState() => _CropImageWidgetState();
}

class _CropImageWidgetState extends State<CropImageWidget> {
  double? height;
  double? originalAspectRatio;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 4) / 2;
    final height = this.height ?? 0;

    if (height == 0) {
      return Material(
        child: InkWell(
          onTap: () async {
            showArticleInfo(context, widget.articleId);
          },
          splashColor: Colors.white,
          child: SizeReportingWidget(
            onSizeChange: (size) {
              setState(() {
                this.height = size.height;
                originalAspectRatio = size.width / size.height;
              });
            },
            child: VCachedNetworkImage(
              fit: BoxFit.cover,
              alignment: Alignment.topLeft,
              fadeInDuration: const Duration(microseconds: 500),
              fadeInCurve: Curves.easeIn,
              imageUrl: widget.url,
              httpHeaders: widget.headers,
              progressIndicatorBuilder: (context, string, progress) {
                return SizedBox(
                  height: 300,
                  child: Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child:
                          CircularProgressIndicator(value: progress.progress),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // 참고: https://github.com/project-violet/violet/pull/363#issuecomment-1908442196
    final cropSize =
        Size(widget.rect.width * width, widget.rect.height * height);
    final cropRawAspectRatio = cropSize.width / cropSize.height;
    final cropRawRect = Rect.fromLTRB(
      widget.rect.left * width,
      widget.rect.top * height,
      widget.rect.right * width,
      widget.rect.bottom * height,
    );

    late final Size viewRawSize;
    late final double translateRatio;

    final rawAspectRatio = width / height;
    if (cropRawAspectRatio / rawAspectRatio <= 1.0) {
      final viewHeight = width / cropRawAspectRatio;
      viewRawSize = Size(width, viewHeight);
      translateRatio = 1.0;
    } else {
      // 실제 viewWidth는 width와 같지만 cropRect, scale의 계산 편의를 위해 height에 상대적으로 설정
      // translateRatio로 후 보정함
      final viewWidth = height * cropRawAspectRatio;
      viewRawSize = Size(viewWidth, height);
      translateRatio = viewWidth / width;
    }

    final cropRect = Rect.fromLTRB(
      cropRawRect.left / viewRawSize.width,
      cropRawRect.top / viewRawSize.height,
      cropRawRect.right / viewRawSize.width,
      cropRawRect.bottom / viewRawSize.height,
    );

    return Material(
      child: InkWell(
        onTap: () async {
          showArticleInfo(context, widget.articleId);
        },
        splashColor: Colors.white,
        child: AspectRatio(
          aspectRatio: cropRawAspectRatio,
          child: Transform.scale(
            scaleX: viewRawSize.width / cropRawRect.width,
            scaleY: viewRawSize.height / cropRawRect.height,
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: Offset(-cropRawRect.left / translateRatio,
                  -cropRawRect.top / translateRatio),
              child: ClipRect(
                clipper: RectClipper(cropRect),
                child: VCachedNetworkImage(
                  fit: BoxFit.contain,
                  alignment: Alignment.topLeft,
                  fadeInDuration: const Duration(microseconds: 500),
                  fadeInCurve: Curves.easeIn,
                  imageUrl: widget.url,
                  httpHeaders: widget.headers,
                  progressIndicatorBuilder: (context, string, progress) {
                    return SizedBox(
                      height: 300,
                      child: Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                              value: progress.progress),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        // ),
      ),
    );
  }
}

class RectClipper extends CustomClipper<Rect> {
  final Rect rect;

  RectClipper(this.rect);

  @override
  Rect getClip(Size size) {
    final x1 = size.width * rect.left;
    final y1 = size.height * rect.top;
    final x2 = size.width * rect.right;
    final y2 = size.height * rect.bottom;
    // print(Rect.fromPoints(Offset(x1, y1), Offset(x2 - x1, y2 - y1)));
    return Rect.fromPoints(Offset(x1, y1), Offset(x2, y2));
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}
