// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

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
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
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

        if (item.artists() != null) {
          for (var artist in item.artists().split('|')) {
            if (artist != '') {
              if (!tagArtist.containsKey(artist)) {
                tagArtist[artist] = <String, int>{};
              }
            }
          }
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            for (var artist in item.artists().split('|')) {
              if (artist == '') continue;
              if (!tagArtist[artist]!.containsKey(index)) {
                tagArtist[artist]![index] = 0;
              }
              tagArtist[artist]![index] = tagArtist[artist]![index]! + 1;
            }
          }
        }

        if (item.groups() != null) {
          for (var artist in item.groups().split('|')) {
            if (artist != '') {
              if (!tagGroup.containsKey(artist)) {
                tagGroup[artist] = <String, int>{};
              }
            }
          }
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            for (var artist in item.groups().split('|')) {
              if (artist == '') continue;
              if (!tagGroup[artist]!.containsKey(index)) {
                tagGroup[artist]![index] = 0;
              }
              tagGroup[artist]![index] = tagGroup[artist]![index]! + 1;
            }
          }
        }

        if (item.uploader() != null) {
          if (!tagUploader.containsKey(item.uploader())) {
            tagUploader[item.uploader()] = <String, int>{};
          }
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            if (!tagUploader[item.uploader()]!.containsKey(index)) {
              tagUploader[item.uploader()]![index] = 0;
            }
            tagUploader[item.uploader()]![index] =
                tagUploader[item.uploader()]![index]! + 1;
          }
        }

        if (item.series() != null) {
          for (var artist in item.series().split('|')) {
            if (artist != '') {
              if (!tagSeries.containsKey(artist)) {
                tagSeries[artist] = <String, int>{};
              }
            }
          }
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            for (var artist in item.series().split('|')) {
              if (artist == '') continue;
              if (!tagSeries[artist]!.containsKey(index)) {
                tagSeries[artist]![index] = 0;
              }
              tagSeries[artist]![index] = tagSeries[artist]![index]! + 1;
            }
          }
        }

        if (item.characters() != null) {
          for (var artist in item.characters().split('|')) {
            if (artist != '') {
              if (!tagCharacter.containsKey(artist)) {
                tagCharacter[artist] = <String, int>{};
              }
            }
          }
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            for (var artist in item.characters().split('|')) {
              if (artist == '') continue;
              if (!tagCharacter[artist]!.containsKey(index)) {
                tagCharacter[artist]![index] = 0;
              }
              tagCharacter[artist]![index] = tagCharacter[artist]![index]! + 1;
            }
          }
        }

        if (item.series() != null && item.characters() != null) {
          for (var series in item.series().split('|')) {
            if (series == '') continue;
            if (!characterSeries.containsKey(series)) {
              characterSeries[series] = <String, int>{};
            }
            for (var character in item.characters().split('|')) {
              if (character == '') continue;
              if (!characterSeries[series]!.containsKey(character)) {
                characterSeries[series]![character] = 0;
              }
              characterSeries[series]![character] =
                  characterSeries[series]![character]! + 1;
            }
          }

          for (var character in item.characters().split('|')) {
            if (character == '') continue;
            if (!seriesCharacter.containsKey(character)) {
              seriesCharacter[character] = <String, int>{};
            }
            for (var series in item.series().split('|')) {
              if (series == '') continue;
              if (!seriesCharacter[character]!.containsKey(series)) {
                seriesCharacter[character]![series] = 0;
              }
              seriesCharacter[character]![series] =
                  seriesCharacter[character]![series]! + 1;
            }
          }
        }

        if (item.series() != null) {
          for (var series in item.series().split('|')) {
            if (series == '') continue;
            if (!seriesSeries.containsKey(series)) {
              seriesSeries[series] = <String, int>{};
            }
            for (var series2 in item.series().split('|')) {
              if (series2 == '' || series == series2) continue;
              if (!seriesSeries[series]!.containsKey(series2)) {
                seriesSeries[series]![series2] = 0;
              }
              seriesSeries[series]![series2] =
                  seriesSeries[series]![series2]! + 1;
            }
          }
        }

        if (item.characters() != null) {
          for (var character in item.characters().split('|')) {
            if (character == '') continue;
            if (!characterCharacter.containsKey(character)) {
              characterCharacter[character] = <String, int>{};
            }
            for (var character2 in item.characters().split('|')) {
              if (character2 == '' || character == character2) continue;
              if (!characterCharacter[character]!.containsKey(character2)) {
                characterCharacter[character]![character2] = 0;
              }
              characterCharacter[character]![character2] =
                  characterCharacter[character]![character2]! + 1;
            }
          }
        }
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
