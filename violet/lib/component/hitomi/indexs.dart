// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/log/log.dart';

// This is used for estimation similiar Aritst/Group/Uplaoder with each others.
class HitomiIndexs {
  // Tag, Index
  // Map<String, int>
  static late Map<String, dynamic> tagIndex;
  // Artist, <Tag Index, Count>
  // Map<String, Map<String, int>>
  static late Map<String, dynamic> tagArtist;
  static late Map<String, dynamic> tagGroup;
  static late Map<String, dynamic> tagUploader;
  static late Map<String, dynamic> tagSeries;
  static late Map<String, dynamic> tagCharacter;
  // Series, <Character, Count>
  // Map<String, Map<String, int>>
  static Map<String, dynamic>? characterSeries;
  // Unmap of character series
  // Character, <Series, Count>
  // Map<String, Map<String, int>>
  static Map<String, dynamic>? seriesCharacter;
  // Series, <Series, Count>
  // Map<String, Map<String, int>>
  static Map<String, dynamic>? seriesSeries;
  // Character, <Character, Count>
  // Map<String, Map<String, int>>
  static Map<String, dynamic>? characterCharacter;
  // Tag, [<Tag, Similarity>]
  static late Map<String, dynamic> relatedTag;

  static Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    final subdir = Platform.isAndroid ? '/data' : '';

    // No data on first run.
    final path2 = File('${directory.path}$subdir/tag-artist.json');
    if (!await path2.exists()) return;
    tagArtist = jsonDecode(await path2.readAsString());
    final path3 = File('${directory.path}$subdir/tag-group.json');
    tagGroup = jsonDecode(await path3.readAsString());
    final path4 = File('${directory.path}$subdir/tag-index.json');
    tagIndex = jsonDecode(await path4.readAsString());
    final path5 = File('${directory.path}$subdir/tag-uploader.json');
    tagUploader = jsonDecode(await path5.readAsString());
    try {
      final path6 = File('${directory.path}$subdir/tag-series.json');
      tagSeries = jsonDecode(await path6.readAsString());
      final path7 = File('${directory.path}$subdir/tag-character.json');
      tagCharacter = jsonDecode(await path7.readAsString());
      final path8 = File('${directory.path}$subdir/character-series.json');
      characterSeries = jsonDecode(await path8.readAsString());
      final path9 = File('${directory.path}$subdir/series-character.json');
      seriesCharacter = jsonDecode(await path9.readAsString());

      final path10 = File('${directory.path}$subdir/character-character.json');
      characterCharacter = jsonDecode(await path10.readAsString());
      final path11 = File('${directory.path}$subdir/series-series.json');
      seriesSeries = jsonDecode(await path11.readAsString());
    } catch (e, st) {
      Logger.error('[Hitomi-Indexs] E: $e\n'
          '$st');
    }

    var relatedData = json.decode(await rootBundle.loadString(
            'assets/locale/tag/related-tag-${TagTranslate.defaultLanguage}.json'))
        as List<dynamic>;
    relatedTag = <String, dynamic>{};
    for (var element in relatedData) {
      var kv = (element as Map<String, dynamic>).entries.first;
      relatedTag[kv.key] = kv.value;
    }
  }

  static List<Tuple2<String, double>> _calculateSimilars(
      Map<String, dynamic> map, String artist) {
    var rr = map[artist];
    var result = <Tuple2<String, double>>[];

    map.forEach((key, value) {
      if (artist == key) return;
      if (key.toLowerCase() == 'n/a') return;

      var dist = Distance.cosineDistance(rr, value);
      result.add(Tuple2<String, double>(key, dist));
    });

    result.sort((x, y) => y.item2.compareTo(x.item2));

    return result;
  }

  static List<Tuple2<String, double>> caclulateSimilarsManual(
      Map<String, dynamic> map, Map<String, dynamic> target) {
    final result = <Tuple2<String, double>>[];

    map.forEach((key, value) {
      if (key.toLowerCase() == 'n/a') return;

      final dist = Distance.cosineDistance(target, value);
      result.add(Tuple2<String, double>(key, dist));
    });

    result.sort((x, y) => y.item2.compareTo(x.item2));

    return result;
  }

  static List<Tuple2<String, double>> calculateSimilarArtists(String artist) {
    return _calculateSimilars(tagArtist, artist);
  }

  static List<Tuple2<String, double>> calculateSimilarGroups(String group) {
    return _calculateSimilars(tagGroup, group);
  }

  static List<Tuple2<String, double>> calculateSimilarUploaders(
      String uploader) {
    return _calculateSimilars(tagUploader, uploader);
  }

  static List<Tuple2<String, double>> calculateSimilarSeries(String series) {
    return _calculateSimilars(tagSeries, series);
  }

  static List<Tuple2<String, double>> calculateSimilarCharacter(
      String character) {
    return _calculateSimilars(tagCharacter, character);
  }

  static List<Tuple2<String, double>> calculateRelatedCharacterSeries(
      String series) {
    if (seriesSeries == null) {
      return _calculateSimilars(characterSeries!, series)
          .where((element) => element.item2 >= 0.000001)
          .toList();
    } else {
      var ll = (seriesSeries![series] as Map<String, dynamic>)
          .entries
          .map((e) => Tuple2<String, double>(e.key, e.value.toDouble()))
          .toList();
      ll.sort((x, y) => y.item2.compareTo(x.item2));
      return ll;
    }
  }

  static List<Tuple2<String, double>> calculateRelatedSeriesCharacter(
      String character) {
    if (characterCharacter == null) {
      return _calculateSimilars(seriesCharacter!, character)
          .where((element) => element.item2 >= 0.000001)
          .toList();
    } else {
      var ll = (characterCharacter![character] as Map<String, dynamic>)
          .entries
          .map((e) => Tuple2<String, double>(e.key, e.value.toDouble()))
          .toList();
      ll.sort((x, y) => y.item2.compareTo(x.item2));
      return ll;
    }
  }

  static List<Tuple2<String, double>> getRelatedCharacters(String series) {
    if (!characterSeries!.containsKey(series)) {
      return <Tuple2<String, double>>[];
    }
    var ll = (characterSeries![series] as Map<String, dynamic>)
        .entries
        .map((e) => Tuple2<String, double>(e.key, e.value.toDouble()))
        .toList();
    ll.sort((x, y) => y.item2.compareTo(x.item2));
    return ll;
  }

  static List<Tuple2<String, double>> getRelatedSeries(String character) {
    if (!seriesCharacter!.containsKey(character)) {
      return <Tuple2<String, double>>[];
    }
    var ll = (seriesCharacter![character] as Map<String, dynamic>)
        .entries
        .map((e) => Tuple2<String, double>(e.key, e.value.toDouble()))
        .toList();
    ll.sort((x, y) => y.item2.compareTo(x.item2));
    return ll;
  }

  static List<Tuple2<String, double>> getRelatedTag(String tag) {
    if (!relatedTag.containsKey(tag)) return <Tuple2<String, double>>[];
    var ll = (relatedTag[tag] as List<dynamic>)
        .map((e) => Tuple2<String, double>(
            (e as Map<String, dynamic>).entries.first.key,
            e.entries.first.value.toDouble()))
        .toList();
    ll.sort((x, y) => y.item2.compareTo(x.item2));
    return ll;
  }
}
