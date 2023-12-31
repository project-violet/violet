// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/duckduckgo/search.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;

class EHSession {
  static Map<String, String> exEhashs = <String, String>{};
  static Map<String, String> ehEhashs = <String, String>{};
  static Map<String, bool> ehashLock = <String, bool>{};
  static Map<String, bool> ehEhashCouldNotFound = <String, bool>{};
  static Map<String, bool> exEhashCouldNotFound = <String, bool>{};
  static EHSession? tryLogin(String id, String pass) {
    return null;
  }

  static Future<String> requestString(String url) async {
    final prefs = await SharedPreferences.getInstance();
    var cookie = prefs.getString('eh_cookies');
    return (await http.get(url, headers: {'Cookie': cookie ?? ''})).body;
  }

  static Future<String?> requestRedirect(String url) async {
    final prefs = await SharedPreferences.getInstance();
    var cookie = prefs.getString('eh_cookies');
    Request req = Request('Get', Uri.parse(url))..followRedirects = false;
    req.headers['Cookie'] = cookie ?? '';
    Client baseClient = Client();
    StreamedResponse response = await baseClient.send(req);
    return response.headers['location'];
  }

  static Future<String> postComment(String url, String content) async {
    final prefs = await SharedPreferences.getInstance();
    var cookie = prefs.getString('eh_cookies');
    return (await http.post(url,
            headers: {'Cookie': cookie ?? ''},
            body: 'commenttext_new=${Uri.encodeFull(content)}'))
        .body;
  }

  static Future<String> getEHashById(String id, [String? from]) async {
    switch (from) {
      case 'e-hentai.org':
        if (ehEhashCouldNotFound[id] == true) {
          Logger.warning(
              '[getEHashById] could not found $id`s ehash from $from');
          throw 'EHASH_LOCK';
        }
      case 'exhentai.org':
        if (exEhashCouldNotFound[id] == true) {
          Logger.warning(
              '[getEHashById] could not found $id`s ehash from $from');
          throw 'EHASH_LOCK';
        }
      default:
        if (ehEhashCouldNotFound[id] == true &&
            exEhashCouldNotFound == true) {
          Logger.warning('[getEHashById] could not found $id`s ehash');
          throw 'EHASH_LOCK';
        }
    }
    if (id.isEmpty) throw Error();
    if (ehashLock[id] == true) {
      Logger.warning('[getEHashById] $id is processing');
      throw 'EHASH_LOCK';
    } else {
      ehashLock[id] = true;
    }
    String? ehash;
    Map<String, String> ehashs = <String, String>{};
    switch (from) {
      case 'e-hentai.org':
        ehashs = ehEhashs;
        break;
      case 'exhentai.org':
        ehashs = exEhashs;
        break;
      default:
        if (from == null) {
          ehashs = <String, String>{};
          ehashs.addAll(exEhashs);
          ehashs.addAll(ehEhashs);
        }
        break;
    }
    if (ehashs[id]?.isNotEmpty ?? false) {
      ehashLock[id] = false;
      return ehashs[id] ?? '';
    }
    try {
      await Future.forEach([
        ...(from == null ? ['e-hentai.org', 'exhentai.org'] : [from])
      ], (host) async {
        // next?${id + 1} search for {e-/ex}hentai.org
        if (ehash != null) return;
        try {
          final listHtml = await EHSession.requestString(
              'https://$host/?next=${(int.parse(id) + 1)}');
          final doc = parse(listHtml);
          final tmpUrl =
              doc.querySelector('a[href*="/g/$id"]')?.attributes['href'] ?? '';
          final tmpEhash = Uri.parse(tmpUrl)
              .path
              .split('/')
              .lastWhere((e) => e.trim().isNotEmpty)
              .trim();
          if (ehash == null && tmpEhash.isNotEmpty) {
            if (host.contains('exhentai')) ehashs = exEhashs;
            if (host.contains('e-hentai')) ehashs = ehEhashs;
            ehash = tmpEhash;
          }
          // ignore: empty_catches
        } catch (e) {}
      });
    } catch (_) {}
    if (ehash != null) {
      ehashLock[id] = false;
      return (ehashs[id] = (ehash ?? ''));
    }
    if (ehash == null && (from?.contains('e-hentai.org') ?? true)) {
      // duckduckgo search (only for search e-hentai.org)
      ehashs = ehEhashs;
      try {
        final ddg = DuckDuckGoSearch();
        final searchRes =
            await ddg.searchProxied('site:e-hentai.org in-url:/g/$id/');
        var foundEncodedUrls = parse(searchRes.body)
            .querySelectorAll('a[href*="${Uri.encodeComponent('/g/$id')}"]')
            .map((encodedUrl) => encodedUrl.attributes['href']?.trim() ?? '')
            .where((encodedUrl) => encodedUrl.trim().isNotEmpty);
        var url = '';
        foundEncodedUrls
            .map((url) => Uri.parse(url).queryParameters)
            .forEach((element) {
          element.forEach((key, value) {
            if (value.contains('/g/$id/')) {
              url = value;
            }
          });
        });
        ehashs[id] = ehash = url.split('/').lastWhere((e) => e.isNotEmpty);
      } catch (_) {}
    }
    if (ehash != null) {
      ehashLock[id] = false;
      return ehash ?? '';
    }
    switch (from) {
      case 'e-hentai.org':
        ehEhashCouldNotFound[id] = true;
        break;
      case 'exhentai.org':
        exEhashCouldNotFound[id] = true;
      default:
        ehEhashCouldNotFound[id] = true;
        exEhashCouldNotFound[id] = true;
    }
    ehashLock[id] = false;
    Logger.warning('[getEHashById] Could not found hash of $id');
    throw 'NOT_FOUND_EHASH';
  }
}
