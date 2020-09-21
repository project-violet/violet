// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/algorithm/distance.dart';

// This is used for estimation similiar Aritst/Group/Uplaoder with each others.
class HitomiIndexs {
  // Tag, Index
  // Map<String, int>
  static Map<String, dynamic> tagIndex;
  // Artist, <Tag Index, Count>
  // Map<String, Map<String, int>>
  static Map<String, dynamic> tagArtist;
  static Map<String, dynamic> tagGroup;
  static Map<String, dynamic> tagUploader;
  static Map<String, dynamic> tagSeries;
  static Map<String, dynamic> tagCharacter;
  // Series, <Character, Count>
  // Map<String, Map<String, int>>
  static Map<String, dynamic> characterSeries;
  // Unmap of character series
  // Character, <Series, Count>
  // Map<String, Map<String, int>>
  static Map<String, dynamic> seriesCharacter;

  static Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();

    // No data on first run.
    final path2 = File('${directory.path}/data/tag-artist.json');
    if (!await path2.exists()) return;
    tagArtist = jsonDecode(await path2.readAsString());
    final path3 = File('${directory.path}/data/tag-group.json');
    tagGroup = jsonDecode(await path3.readAsString());
    final path4 = File('${directory.path}/data/tag-index.json');
    tagIndex = jsonDecode(await path4.readAsString());
    final path5 = File('${directory.path}/data/tag-uploader.json');
    tagUploader = jsonDecode(await path5.readAsString());
    try {
      final path6 = File('${directory.path}/data/tag-series.json');
      tagSeries = jsonDecode(await path6.readAsString());
      final path7 = File('${directory.path}/data/tag-character.json');
      tagCharacter = jsonDecode(await path7.readAsString());
      final path8 = File('${directory.path}/data/character-series.json');
      characterSeries = jsonDecode(await path8.readAsString());
      final path9 = File('${directory.path}/data/series-character.json');
      seriesCharacter = jsonDecode(await path9.readAsString());
    } catch (e) {}
  }

  static List<Tuple2<String, double>> _calculateSimilars(
      Map<String, dynamic> map, String artist) {
    var rr = map[artist];
    var result = List<Tuple2<String, double>>();

    map.forEach((key, value) {
      if (artist == key) return;
      if (key.toUpperCase() == 'n/a') return;

      var dist = Distance.cosineDistance(rr, value);
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
    return _calculateSimilars(characterSeries, series)
        .where((element) => element.item2 >= 0.000001)
        .toList();
  }

  static List<Tuple2<String, double>> calculateRelatedSeriesCharacter(
      String character) {
    return _calculateSimilars(seriesCharacter, character)
        .where((element) => element.item2 >= 0.000001)
        .toList();
  }

  static List<Tuple2<String, double>> getRelatedCharacters(String series) {
    var ll = (characterSeries[series] as Map<String, dynamic>)
        .entries
        .map((e) => Tuple2<String, double>(e.key, e.value.toDouble()))
        .toList();
    ll.sort((x, y) => y.item2.compareTo(x.item2));
    return ll;
  }

  static List<Tuple2<String, double>> getRelatedSeries(String character) {
    var ll = (seriesCharacter[character] as Map<String, dynamic>)
        .entries
        .map((e) => Tuple2<String, double>(e.key, e.value.toDouble()))
        .toList();
    ll.sort((x, y) => y.item2.compareTo(x.item2));
    return ll;
  }
}
