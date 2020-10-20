// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:intl/intl.dart';
import 'package:tuple/tuple.dart';

class EHArticle {
  String thumbnail;
  String title;
  String subTitle;
  String type;
  String uploader;

  // Left side of article info
  String posted;
  String parent;
  String visible;
  String language;
  String fileSize;
  int length;
  int favorited;

  // Right side of article info
  String reclass;
  List<String> languages;
  List<String> group;
  List<String> parody;
  List<String> character;
  List<String> artist;
  List<String> male;
  List<String> female;
  List<String> misc;

  List<Tuple3<DateTime, String, String>> comment;
  List<String> imageLink;
}

class EHResultArticle {
  String url;

  String thumbnail;
  String title;

  String uploader;
  String published;
  String files;
  String type;

  Map<String, List<String>> descripts;
}

// E-Hentai, EX-Hentai Parser
// You can use both of the previous.
class EHParser {
  static RegExp _thumbnailPattern =
      RegExp(r'https://(exhentai|ehgt).org/.*?(?=\))');

  // ex: https://exhentai.org/g/1212168/421ef300a8/
  static List<String> getImagesUrl(String html) {
    var doc = parse(html).querySelector("div[id='gdt']");
    var result = List<String>();
    doc.querySelectorAll('div').forEach((element) {
      var a = element.querySelector('a');
      if (a == null) return;
      var url = element.querySelector('a').attributes['href'];
      if (!result.contains(url)) result.add(url);
    });
    return result;
  }

  // ex: https://exhentai.org/s/df24b19548/1212549-2
  static String getImagesAddress(String html) {
    var doc = parse(html).querySelector("div[id='i1']");
    return doc.querySelector("div[id='i3'] a img").attributes['src'];
  }

  // ex: https://exhentai.org/g/1212168/421ef300a8/
  // ex: https://exhentai.org/g/1212396/71a853083e/ //  5 pages
  // ex: https://exhentai.org/g/1201400/48f9b8e20a/ // 43 pages
  static List<String> getPagesUrl(String html, {String url}) {
    var doc = parse(html).querySelector("div.gtb");

    var url = List<String>();
    try {
      var rr = doc.querySelectorAll("table tbody tr td[onclick*='document']");
      if (rr.length != 0) {
        doc
            .querySelectorAll("table tbody tr td[onclick*='document']")
            .forEach((element) {
          var a = element.querySelector('a');
          if (a != null) url.add(a.attributes['href']);
        });
      } else {
        url.add(doc
                .querySelector("table tbody tr td.ptds")
                .querySelector('a')
                .attributes['href'] +
            '?p=0');
      }
    } catch (e) {
      url.add(doc
              .querySelector("table tbody tr td.ptds")
              .querySelector('a')
              .attributes['href'] +
          '?p=0');
    }

    int max = 0;
    url.forEach((element) {
      int value = int.tryParse(element.split('?p=')[1]);
      if (value != null) {
        if (max < value) max = value;
      }
    });

    if (url.length == 0) return null;

    var result = List<String>();
    var prefix = url[0].split('?p=')[0];
    for (int i = 0; i <= max; i++) result.add(prefix + '?p=' + i.toString());
    return result;
  }

  static EHArticle parseArticleData(String html) {
    var article = EHArticle();
    var h = parse(html);
    var doc = h.querySelector("div.gm");

    article.thumbnail = _thumbnailPattern
        .stringMatch(
            doc.querySelector("div[id=gleft] div div").attributes['style'])
        .toString();

    article.title = doc.querySelector("div[id='gd2'] h1[id='gn']").text;
    article.subTitle = doc.querySelector("div[id='gd2'] h1[id='gj']").text;

    article.uploader = doc.querySelector("div[id='gmid'] div[id='gdn'] a").text;

    var nodeStatic =
        doc.querySelectorAll("div[id='gmid'] div[id='gdd'] table tr");

    article.posted = nodeStatic[0].querySelector("td[class='gdt2']").text;
    article.parent = nodeStatic[1].querySelector("td[class='gdt2']").text;
    article.visible = nodeStatic[2].querySelector("td[class='gdt2']").text;
    article.language = nodeStatic[3].querySelector("td[class='gdt2']").text;
    article.fileSize = nodeStatic[4].querySelector("td[class='gdt2']").text;
    article.length = int.tryParse(nodeStatic[5]
        .querySelector("td[class='gdt2']")
        .text
        .replaceAll('pages', '')
        .trim());
    article.favorited = int.tryParse(nodeStatic[6]
        .querySelector("td[class='gdt2']")
        .text
        .replaceAll('times', '')
        .trim());

    var nodesData =
        doc.querySelectorAll("div[id='gmid'] div[id='taglist'] table tr");
    var info = Map<String, List<String>>();

    nodesData.forEach((element) {
      try {
        info[element.querySelector('td').text.trim()] = element
            .querySelectorAll('td')[1]
            .querySelectorAll('div')
            .map((x) => x.querySelector('a').text)
            .toList();
      } catch (e) {}
    });

    if (info.containsKey("language:")) article.languages = info["language:"];
    if (info.containsKey("group:")) article.group = info["group:"];
    if (info.containsKey("parody:")) article.parody = info["parody:"];
    if (info.containsKey("character:")) article.character = info["character:"];
    if (info.containsKey("artist:")) article.artist = info["artist:"];
    if (info.containsKey("male:")) article.male = info["male:"];
    if (info.containsKey("female:")) article.female = info["female:"];
    if (info.containsKey("misc:")) article.misc = info["misc:"];

    var nodeComments = h.querySelectorAll("div[id='cdiv'] > div.c1");
    var comments = List<Tuple3<DateTime, String, String>>();

    if (nodeComments != null) {
      var hu = HtmlUnescape();
      var df = DateFormat('dd MMMM yyyy, H:m');
      nodeComments.forEach((element) {
        var date =
            hu.convert(element.querySelector("div.c2 div.c3").text.trim());
        var author =
            hu.convert(element.querySelector("div.c2 div.c3 > a").text.trim());
        var contents = hu.convert(element
            .querySelector("div.c6")
            .innerHtml
            .replaceAll('<br>', '\r\n'));
        comments.add(Tuple3<DateTime, String, String>(
            df.parse(date
                .substring(0, date.indexOf(' by'))
                .substring('Posted on '.length)),
            author,
            contents));
      });
    }

    comments.sort((x, y) => x.item1.compareTo(y.item1));
    article.comment = comments;

    return article;
  }

  // ex: https://exhentai.org/?inline_set=dm_t
  static List<EHResultArticle> parseReulstPageThumbnailView(String html) {
    var result = List<EHResultArticle>();

    var nodes = parse(html).querySelectorAll('div.itg > div.id1');

    nodes.forEach((element) {
      try {
        var article = EHResultArticle();

        article.url = element.querySelector('div.id2 a').attributes['href'];

        try {
          article.thumbnail =
              element.querySelector('div.id3 a img').attributes['src'];
        } catch (e) {}
        article.title = element.querySelector('div.id2 a').text;

        article.files = element.querySelector('div.id42').text;
        article.type = element.querySelector('div.id41').attributes['title'];

        result.add(article);
      } catch (e) {}
    });

    return result;
  }

  // ex: https://exhentai.org/?inline_set=dm_l
  static List<EHResultArticle> parseReulstPageListView(String html) {
    var result = List<EHResultArticle>();

    var nodes = parse(html).querySelectorAll('div.itg > tr');

    if (nodes.length > 1) nodes.removeAt(0);

    nodes.forEach((element) {
      try {
        var article = EHResultArticle();
        var tds = element.querySelectorAll('td');

        article.url = tds[2].querySelector('div.it5 a').attributes['href'];

        try {
          article.thumbnail =
              tds[2].querySelector('div.it2 img').attributes['src'];
        } catch (e) {}
        article.title = tds[2].querySelector('div.it5 a').text;

        article.uploader = tds[3].querySelector('div > a').attributes['href'];
        article.published = tds[1].text;
        article.type = tds[0].querySelector('a img').attributes['alt'];

        result.add(article);
      } catch (e) {}
    });

    return result;
  }

  // ex: https://exhentai.org/?inline_set=dm_e
  // The html source is broken. Therefore, you have to do fucking like this.
  static List<EHResultArticle> parseReulstPageExtendedListView(String html) {
    var result = List<EHResultArticle>();

    var q = List<Element>();
    parse(html)
        .querySelectorAll("table.itg.glte")
        .forEach((element) => q.add(element));

    while (q.isNotEmpty) {
      var node = q[0];
      q.removeAt(0);

      try {
        var article = EHResultArticle();

        article.url = node.querySelector('a').attributes['href'];
        try {
          article.thumbnail = node.querySelector('img').attributes['src'];
        } catch (e) {}

        var g13 = node.querySelectorAll('td')[1].querySelector('div > div');
        var g13div = g13.querySelectorAll('div');

        article.type = g13div[0].text.toLowerCase();
        article.published = g13div[1].text;
        article.uploader = g13div[3].text;
        article.files = g13div[4].text;

        var gref =
            node.querySelectorAll('td')[1].querySelector('div > a > div');

        article.title = gref.querySelector('div').text;

        try {
          var dict = Map<String, List<String>>();

          var tagarea = gref.querySelector('div > table');

          if (tagarea != null) {
            gref
                .querySelector('div > table')
                .querySelectorAll('tr')
                .forEach((element) {
              var cont = element.querySelector('td').text.trim();
              cont = cont.substring(0, cont.length - 1);

              var cc = List<String>();

              element
                  .querySelectorAll('td')[1]
                  .querySelectorAll('div')
                  .forEach((element) => cc.add(element.text));

              dict[cont] = cc;
            });
          }
          article.descripts = dict;
        } catch (e) {
          print(e);
        }

        result.add(article);

        var next = node.querySelectorAll('tr');

        if (next != null) q.addAll(next);
      } catch (e) {}
    }

    return result;
  }

  // ex: https://exhentai.org/?inline_set=dm_m
  static List<EHResultArticle> parseReulstPageMinimalListView(String html) {
    var result = List<EHResultArticle>();

    var nodes = parse(html).querySelectorAll("table[class='itg gltm'] > tr");

    if (nodes.length > 1) nodes.removeAt(0);

    nodes.forEach((element) {
      var article = EHResultArticle();

      article.type =
          element.querySelector('td > div').text.trim().toLowerCase();
      article.thumbnail = element.querySelector('img').attributes['src'];
      if (article.thumbnail.startsWith('data'))
        article.thumbnail = element.querySelector('img').attributes['data-src'];
      article.published = element
          .querySelectorAll('td')[1]
          .querySelectorAll('div')[1]
          .querySelectorAll('div')[1]
          .querySelectorAll('div')[0]
          .querySelectorAll('div')[1]
          .text
          .trim();
      article.files = element
          .querySelectorAll('td')[1]
          .querySelectorAll('div')[1]
          .querySelectorAll('div')[1]
          .querySelectorAll('div')[1]
          .querySelectorAll('div')[1]
          .text
          .trim();

      article.url = element
          .querySelectorAll('td')[3]
          .querySelector('a')
          .attributes['href'];
      article.title =
          element.querySelectorAll('td')[3].querySelector('a  div').text.trim();
      article.uploader =
          element.querySelectorAll('td')[5].querySelector('div a').text.trim();

      result.add(article);
    });

    return result;
  }
}
