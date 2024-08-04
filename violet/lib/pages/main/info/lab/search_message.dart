// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/main/info/lab/search_message_rank.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/util/evict_image_urls.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/v_cached_network_image.dart';

class LabSearchMessage extends StatefulWidget {
  const LabSearchMessage({super.key});

  @override
  State<LabSearchMessage> createState() => _LabSearchMessageState();
}

class _LabSearchMessageState extends State<LabSearchMessage> {
  List<Tuple5<double, int, int, double, List<double>>> messages =
      <Tuple5<double, int, int, double, List<double>>>[];
  TextEditingController text = TextEditingController(text: '은근슬쩍');
  String latestSearch = '은근슬쩍';
  List<Tuple3<String, String, int>>? autocompleteTarget;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      var tmessages = (await VioletServer.searchMessage('contains', text.text))
          as List<dynamic>;
      messages = tmessages
          .map((e) => Tuple5<double, int, int, double, List<double>>(
              double.parse(e['MatchScore'] as String),
              e['Id'] as int,
              e['Page'] as int,
              e['Correctness'] as double,
              (e['Rect'] as List<dynamic>)
                  .map((e) => double.parse(e.toString()))
                  .toList()))
          .toList();

      if (_height == null) {
        _height = List<double>.filled(messages.length, 0);
        _keys =
            List<GlobalKey>.generate(messages.length, (index) => GlobalKey());
        _urls = List<String>.filled(messages.length, '');
      }

      await ScriptManager.refresh();

      setState(() {});
    });

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      const url =
          'https://raw.githubusercontent.com/project-violet/violet-message-search/master/SORT-COMBINE.json';

      var m = jsonDecode((await http.get(url)).body) as Map<String, dynamic>;

      autocompleteTarget = m.entries
          .map((e) => Tuple3<String, String, int>(
              e.key, TagTranslate.disassembly(e.key), e.value as int))
          .toList();

      autocompleteTarget!.sort((x, y) => y.item3.compareTo(x.item3));

      setState(() {});
    });
  }

  @override
  void dispose() {
    PaintingBinding.instance.imageCache.clear();
    imageCache.clearLiveImages();
    imageCache.clear();
    evictImageUrls(_urls);
    super.dispose();
  }

  List<double>? _height;
  List<GlobalKey>? _keys;
  List<String>? _urls;
  String selected = 'Contains';

  @override
  Widget build(BuildContext context) {
    ImageCache imageCache = PaintingBinding.instance.imageCache;
    if (imageCache.currentSizeBytes >= (1024 + 256) << 20) {
      imageCache.clear();
      imageCache.clearLiveImages();
    }

    final height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width - 16;
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(0),
              cacheExtent: height * 3.0,
              itemCount: messages.length,
              itemBuilder: (BuildContext ctxt, int index) {
                // if (messages.length == 0) return Container();
                var e = messages[index];

                return FutureBuilder(
                  future: Future.delayed(const Duration(milliseconds: 100))
                      .then((value) async {
                    VioletImageProvider provider;
                    if (ProviderManager.isExists(e.item2)) {
                      provider = await ProviderManager.get(e.item2);
                    } else {
                      final query =
                          (await HentaiManager.idSearch(e.item2.toString()))
                              .results;
                      provider = await HentaiManager.getImageProvider(query[0]);
                      await provider.init();
                      ProviderManager.insert(query[0].id(), provider);
                    }

                    return Tuple2(
                        _urls![index] = await provider.getImageUrl(e.item3),
                        await provider.getHeader(e.item3));
                  }),
                  builder: (context,
                      AsyncSnapshot<Tuple2<String, Map<String, String>>>
                          snapshot) {
                    if (!snapshot.hasData) {
                      return Column(
                        children: [
                          SizedBox(
                            height:
                                _height![index] != 0 ? _height![index] : 300,
                            child: const Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                          ListTile(
                            title: Text('${e.item2} (${e.item3 + 1} Page)'),
                            subtitle: Text('Score: ${e.item1}'),
                          ),
                        ],
                      );
                    }
                    return InkWell(
                      onTap: () async {
                        FocusScope.of(context).unfocus();
                        showArticleInfo(context, e.item2);
                      },
                      splashColor: Colors.white,
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                constraints: BoxConstraints(
                                    minHeight: _height![index] != 0
                                        ? _height![index]
                                        : 300),
                                child: VCachedNetworkImage(
                                  key: _keys![index],
                                  fit: BoxFit.cover,
                                  fadeInDuration:
                                      const Duration(microseconds: 500),
                                  fadeInCurve: Curves.easeIn,
                                  imageUrl: snapshot.data!.item1,
                                  httpHeaders: snapshot.data!.item2,
                                  progressIndicatorBuilder:
                                      (context, string, progress) {
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
                                  imageBuilder:
                                      (context, imageProvider, child) {
                                    if (_height![index] == 0 ||
                                        _height![index] == 300) {
                                      Future.delayed(
                                              const Duration(milliseconds: 50))
                                          .then((value) {
                                        try {
                                          final RenderBox renderBoxRed =
                                              _keys![index]
                                                      .currentContext!
                                                      .findRenderObject()!
                                                  as RenderBox;
                                          final sizeRender = renderBoxRed.size;
                                          if (sizeRender.height != 300) {
                                            _height![index] =
                                                width / sizeRender.aspectRatio;
                                          }
                                        } catch (_) {}
                                      });
                                    }
                                    return child;
                                  },
                                ),
                              ),
                              FutureBuilder(
                                future: _calculateImageDimension(
                                    snapshot.data!.item1, snapshot.data!.item2),
                                builder:
                                    (context, AsyncSnapshot<Size> snapshot2) {
                                  if (!snapshot2.hasData) return Container();

                                  var brtx = e.item5[0];
                                  var brty = e.item5[1];
                                  var brbx = e.item5[2];
                                  var brby = e.item5[3];

                                  var w = snapshot2.data!.width;

                                  var ratio = width / w;

                                  return Positioned(
                                    top: brty * ratio - 4,
                                    left: brtx * ratio - 4,
                                    child: SizedBox(
                                      width: (brbx - brtx) * ratio + 8,
                                      height: (brby - brty) * ratio + 8,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            width: 3,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          ListTile(
                            title: Text('${e.item2} (${e.item3 + 1} Page)'),
                            subtitle: Text('Score: ${e.item1}'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Row(
            children: [
              Container(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton(
                  items: ['Contains', 'Similar', 'LCS']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  value: selected,
                  onChanged: (String? value) async {
                    if (value == selected) return;
                    messages =
                        <Tuple5<double, int, int, double, List<double>>>[];

                    setState(() {
                      selected = value!;
                    });
                    var tmessages = (await VioletServer.searchMessage(
                        selected.toLowerCase(), text.text)) as List<dynamic>;
                    messages = tmessages
                        .map((e) =>
                            Tuple5<double, int, int, double, List<double>>(
                                double.parse(e['MatchScore'] as String),
                                e['Id'] as int,
                                e['Page'] as int,
                                e['Correctness'] as double,
                                (e['Rect'] as List<dynamic>)
                                    .map((e) => double.parse(e.toString()))
                                    .toList()))
                        .toList();

                    evictImageUrls(_urls);

                    _height = List<double>.filled(messages.length, 0);
                    _keys = List<GlobalKey>.generate(
                        messages.length, (index) => GlobalKey());
                    _urls = List<String>.filled(messages.length, '');

                    setState(() {});
                  },
                ),
              ),
              Container(width: 4),
              Expanded(
                child: TypeAheadField(
                  suggestionsCallback: (pattern) async {
                    if (autocompleteTarget == null) {
                      return <Tuple3<String, String, int>>[];
                    }

                    var ppattern = TagTranslate.disassembly(pattern);

                    return autocompleteTarget!
                        .where((element) => element.item2.startsWith(ppattern))
                        .toList()
                      ..addAll(autocompleteTarget!
                          .where((element) =>
                              !element.item2.startsWith(ppattern) &&
                              element.item2.contains(ppattern))
                          .toList());
                  },
                  itemBuilder:
                      (context, Tuple3<String, String, int> suggestion) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0.0, horizontal: 16.0),
                      title: Text(suggestion.item1),
                      trailing: Text(
                        '${suggestion.item3}회',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10.0),
                      ),
                      dense: true,
                    );
                  },
                  direction: AxisDirection.up,
                  onSuggestionSelected:
                      (Tuple3<String, String, int> suggestion) {
                    text.text = suggestion.item1;
                    setState(() {});
                    Future.delayed(const Duration(milliseconds: 100))
                        .then((value) async {
                      _onModifiedText();
                    });
                  },
                  hideOnEmpty: true,
                  hideOnLoading: true,
                  textFieldConfiguration: TextFieldConfiguration(
                    decoration:
                        const InputDecoration.collapsed(hintText: '대사 입력'),
                    controller: text,
                    // autofocus: true,
                    onEditingComplete: _onModifiedText,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.segment),
                color: Colors.grey,
                onPressed: () async {
                  var search = await PlatformNavigator.navigateSlide<String>(
                      context, const SearchMessageRankPage());

                  if (search == null || search == '') return;

                  text.text = search;
                  setState(() {});
                  Future.delayed(const Duration(milliseconds: 100))
                      .then((value) async {
                    _onModifiedText();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                color: Colors.grey,
                onPressed: () async {
                  await showOkDialog(
                      context,
                      '대사를 검색해 작품을 찾아보세요! 현재 2023.09.30까지 업로드된 작품들을 지원됩니다.',
                      '대사 검색기');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onModifiedText() async {
    if (latestSearch == text.text) return;
    latestSearch = text.text;
    messages = <Tuple5<double, int, int, double, List<double>>>[];

    setState(() {});
    var tmessages =
        (await VioletServer.searchMessage(selected.toLowerCase(), text.text))
            as List<dynamic>;
    messages = tmessages
        .map((e) => Tuple5<double, int, int, double, List<double>>(
            double.parse(e['MatchScore'] as String),
            e['Id'] as int,
            e['Page'] as int,
            double.parse(e['Correctness'].toString()),
            (e['Rect'] as List<dynamic>)
                .map((e) => double.parse(e.toString()))
                .toList()))
        .toList();

    evictImageUrls(_urls);

    _height = List<double>.filled(messages.length, 0);
    _keys = List<GlobalKey>.generate(messages.length, (index) => GlobalKey());
    _urls = List<String>.filled(messages.length, '');

    await ScriptManager.refresh();

    setState(() {});
  }

  Future<Size> _calculateImageDimension(
      String url, Map<String, String> header) {
    Completer<Size> completer = Completer();
    Image image =
        Image(image: CachedNetworkImageProvider(url, headers: header));
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          var myImage = image.image;
          Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
          completer.complete(size);
        },
      ),
    );
    return completer.future;
  }
}
