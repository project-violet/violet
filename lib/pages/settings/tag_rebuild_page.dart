// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';

class TagRebuildPage extends StatefulWidget {
  const TagRebuildPage({super.key});

  @override
  State<TagRebuildPage> createState() => _TagRebuildPageState();
}

class _TagRebuildPageState extends State<TagRebuildPage> {
  String baseString = '';

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      await indexing();

      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(1)),
          boxShadow: [
            BoxShadow(
              color: Settings.themeWhat
                  ? Colors.black.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 1,
              offset: const Offset(0, 3), // changes position of shadow
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Card(
              color: Settings.themeWhat
                  ? Palette.darkThemeBackground
                  : Palette.lightThemeBackground,
              elevation: 100,
              child: SizedBox(
                child: SizedBox(
                  width: 280,
                  height: (56 * 4 + 16).toDouble(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                    child: Stack(
                      children: [
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 33),
                            child: Text(
                              baseString,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void insert(Map<String, int> map, dynamic qr) {
    if (qr == null) return;
    if (qr is! String) return;
    if (qr.isEmpty) return;

    for (var tag in qr.split('|')) {
      if (tag.isEmpty) {
        continue;
      }

      map.update(tag, (value) => value + 1, ifAbsent: () => 1);
    }
  }

  void insertSingle(Map<String, int> map, dynamic qr) {
    if (qr == null) return;
    if (qr as String == '') return;
    var str = qr;
    if (str != '') {
      if (!map.containsKey(str)) map[str] = 0;
      map[str] = map[str]! + 1;
    }
  }

  Future indexing() async {
    QueryManager qm;
    qm = QueryManager.queryPagination(HitomiManager.translate2query(
        '${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}'));
    qm.itemsPerPage = 50000;

    var tags = <String, int>{};
    var languages = <String, int>{};
    var artists = <String, int>{};
    var groups = <String, int>{};
    var types = <String, int>{};
    var uploaders = <String, int>{};
    var series = <String, int>{};
    var characters = <String, int>{};
    var classes = <String, int>{};

    var tagIndex = <String, int>{};
    var tagArtist = <String, Map<String, int>>{};
    var tagGroup = <String, Map<String, int>>{};
    var tagUploader = <String, Map<String, int>>{};
    var tagSeries = <String, Map<String, int>>{};
    var tagCharacter = <String, Map<String, int>>{};

    var seriesSeries = <String, Map<String, int>>{};
    var seriesCharacter = <String, Map<String, int>>{};

    var characterCharacter = <String, Map<String, int>>{};
    var characterSeries = <String, Map<String, int>>{};

    int i = 0;
    while (true) {
      setState(() {
        baseString = '${Translations.instance!.trans('dbdindexing')}[$i/20]';
      });

      var ll = await qm.next();
      print(ll.length);
      for (var item in ll) {
        insert(tags, item.tags());
        insert(artists, item.artists());
        insert(groups, item.groups());
        insert(series, item.series());
        insert(characters, item.characters());
        insertSingle(languages, item.language());
        insertSingle(types, item.type());
        insertSingle(uploaders, item.uploader());
        insertSingle(classes, item.classname());

        if (item.tags() == null) continue;

        void updateRelativeTag(targets, updateTo) {
          if (targets == null) return;

          for (var target in targets.split('|')) {
            if (target != '') {
              if (!updateTo.containsKey(target)) {
                updateTo[target] = <String, int>{};
              }
            }
          }
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;
            final index = tagIndex[tag].toString();
            for (var target in targets.split('|')) {
              if (target == '') continue;
              if (!updateTo[target]!.containsKey(index)) {
                updateTo[target]![index] = 0;
              }
              updateTo[target]![index] = updateTo[target]![index]! + 1;
            }
          }
        }

        updateRelativeTag(item.artists(), tagArtist);
        updateRelativeTag(item.groups(), tagGroup);
        updateRelativeTag(item.series(), tagSeries);
        updateRelativeTag(item.characters(), tagCharacter);
        updateRelativeTag(item.uploader(), tagUploader);

        void updateRelativeFrom(sources, targets, updateTo, [allowEq = false]) {
          if (sources == null || targets == null) return;

          for (var source in sources.split('|')) {
            if (source == '') continue;
            if (!updateTo.containsKey(source)) {
              updateTo[source] = <String, int>{};
            }
            for (var target in targets.split('|')) {
              if (target == '') continue;
              if (allowEq && (source == target)) continue;
              if (!updateTo[source]!.containsKey(target)) {
                updateTo[source]![target] = 0;
              }
              updateTo[source]![target] = updateTo[source]![target]! + 1;
            }
          }
        }

        updateRelativeFrom(item.series(), item.characters(), characterSeries);
        updateRelativeFrom(item.characters(), item.series(), seriesCharacter);
        updateRelativeFrom(item.series(), item.series(), seriesSeries, false);
        updateRelativeFrom(
            item.characters(), item.characters(), characterCharacter, false);
      }

      if (ll.isEmpty) {
        var index = {
          'tag': tags,
          'artist': artists,
          'group': groups,
          'series': series,
          'lang': languages,
          'type': types,
          'uploader': uploaders,
          'character': characters,
          'class': classes,
        };
        final subdir = Platform.isAndroid ? '/data' : '';

        final directory = await getApplicationDocumentsDirectory();
        final path1 = File('${directory.path}$subdir/index.json');
        if (path1.existsSync()) path1.deleteSync();
        path1.writeAsString(jsonEncode(index));
        print(index);

        final path2 = File('${directory.path}$subdir/tag-artist.json');
        if (path2.existsSync()) path2.deleteSync();
        path2.writeAsString(jsonEncode(tagArtist));
        final path3 = File('${directory.path}$subdir/tag-group.json');
        if (path3.existsSync()) path3.deleteSync();
        path3.writeAsString(jsonEncode(tagGroup));
        final path4 = File('${directory.path}$subdir/tag-index.json');
        if (path4.existsSync()) path4.deleteSync();
        path4.writeAsString(jsonEncode(tagIndex));
        final path5 = File('${directory.path}$subdir/tag-uploader.json');
        if (path5.existsSync()) path5.deleteSync();
        path5.writeAsString(jsonEncode(tagUploader));
        final path6 = File('${directory.path}$subdir/tag-series.json');
        if (path6.existsSync()) path6.deleteSync();
        path6.writeAsString(jsonEncode(tagSeries));
        final path7 = File('${directory.path}$subdir/tag-character.json');
        if (path7.existsSync()) path7.deleteSync();
        path7.writeAsString(jsonEncode(tagCharacter));

        final path8 = File('${directory.path}$subdir/character-series.json');
        if (path8.existsSync()) path8.deleteSync();
        path8.writeAsString(jsonEncode(characterSeries));
        final path9 = File('${directory.path}$subdir/series-character.json');
        if (path9.existsSync()) path9.deleteSync();
        path9.writeAsString(jsonEncode(seriesCharacter));
        final path10 =
            File('${directory.path}$subdir/character-character.json');
        if (path10.existsSync()) path10.deleteSync();
        path10.writeAsString(jsonEncode(characterCharacter));
        final path11 = File('${directory.path}$subdir/series-series.json');
        if (path11.existsSync()) path11.deleteSync();
        path11.writeAsString(jsonEncode(seriesSeries));

        break;
      }
      i++;
    }
  }
}
