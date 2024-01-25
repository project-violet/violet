// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
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

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

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

          return MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            itemCount: imgs.length,
            cacheExtent: height * 3.0,
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
                e.aspectRatio(),
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
    double aspectRatio,
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
        final width = (MediaQuery.of(context).size.width - 4) / 2;
        final cropRawAspectRatio =
            calculateCropRawAspectRatio(width, aspectRatio, rect);

        if (!snapshot.hasData) {
          return AspectRatio(
            aspectRatio: cropRawAspectRatio,
            child: const Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        return AspectRatio(
          aspectRatio: cropRawAspectRatio,
          child: CropImageWidget(
            articleId: articleId,
            page: page,
            url: snapshot.data!.item1,
            headers: snapshot.data!.item2,
            rect: rect,
            aspectRatio: aspectRatio,
          ),
        );
      },
    );
  }
}

double calculateCropRawAspectRatio(
    double width, double aspectRatio, Rect cropRect) {
  final height = width / aspectRatio;

  final cropSize = Size(cropRect.width * width, cropRect.height * height);
  return cropSize.width / cropSize.height;
}

class CropImageWidget extends StatefulWidget {
  final String url;
  final Map<String, String> headers;
  final int articleId;
  final int page;
  final Rect rect;
  final double aspectRatio;

  const CropImageWidget({
    super.key,
    required this.url,
    required this.headers,
    required this.articleId,
    required this.page,
    required this.rect,
    required this.aspectRatio,
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
    final height = width / widget.aspectRatio;

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

    final imageArea = AspectRatio(
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
                      child:
                          CircularProgressIndicator(value: progress.progress),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    final pageOverlay = Align(
      alignment: FractionalOffset.bottomRight,
      child: Transform(
        transform: Matrix4.identity()..scale(0.9),
        child: Theme(
          data: ThemeData(
            useMaterial3: false,
            canvasColor: Colors.transparent,
          ),
          child: RawChip(
            labelPadding: const EdgeInsets.all(0.0),
            label: Text(
              '${widget.articleId} (${widget.page + 1} Page)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.0,
              ),
            ),
            elevation: 6.0,
            shadowColor: Colors.grey[60],
            padding: const EdgeInsets.symmetric(
              vertical: 6.0,
              horizontal: 10.0,
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        imageArea,
        pageOverlay,
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                showArticleInfo(context, widget.articleId);
              },
              onDoubleTap: () async {
                _showViewer(widget.articleId);
              },
              highlightColor:
                  Theme.of(context).highlightColor.withOpacity(0.15),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showViewer(int articleId) async {
    if (Settings.useVioletServer) {
      Future.delayed(const Duration(milliseconds: 100)).then((value) async {
        await VioletServer.view(articleId);
      });
    }

    await (await User.getInstance()).insertUserLog(articleId, 0);

    var prov = await ProviderManager.get(articleId);

    await prov.init();

    var headers = await prov.getHeader(0);

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return Provider<ViewerPageProvider>.value(
              value: ViewerPageProvider(
                uris: List<String>.filled(prov.length(), ''),
                useProvider: true,
                provider: prov,
                headers: headers,
                id: articleId,
                title: '<No Query>',
                jumpPage: widget.page,
              ),
              child: const ViewerPage());
        },
      ),
    ).then((value) async {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    });
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
    return Rect.fromPoints(Offset(x1, y1), Offset(x2, y2));
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}
