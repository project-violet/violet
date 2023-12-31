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
  static Map<String, bool> ehEhashCouldNotFound = <String, bool>{};
  static Map<String, bool> exEhashCouldNotFound = <String, bool>{};
  static Map<String, bool> ehashLock = <String, bool>{};
  static EHSession? tryLogin(String id, String pass) {
    return null;
  }

  static Future<void> refreshExhentaiCookie() async {
    final prefs = await SharedPreferences.getInstance();
    var ckTmp = prefs.getString('eh_cookies');
    var ck = ckTmp ?? '';
    ck = ck
        .split(';')
        .where((cookieKeyVal) => cookieKeyVal.contains('='))
        .join(';');
    if (ck.isEmpty) return;
    ck = ck
        .split(';')
        .where((cookieKeyVal) => !cookieKeyVal.trim().startsWith('igneous='))
        .join(';');
    final res = await http.get('https://exhentai.org', headers: {'Cookie': ck});
    res.headers.forEach((key, value) {
      if (key == 'set-cookie') {
        final firstCookieString = value.split(';')[0];
        final firstCookieKey = firstCookieString
            .substring(0, firstCookieString.indexOf('='))
            .trim();
        final firstCookieValue = firstCookieString
            .substring(
                firstCookieString.indexOf('=') + 1, firstCookieString.length)
            .trim();
        if (firstCookieKey == 'igneous' && firstCookieValue == 'mystery') {
          return;
        }
        var ckTmp2 = ck
            .split(';')
            .where((element) => element.trim().isNotEmpty)
            .toList();
        ckTmp2.add('$firstCookieKey=$firstCookieValue');
        ck = ckTmp2.join(';');
      }
    });
    await prefs.setString('eh_cookies', ck);
  }

  static Future<void> refreshEhentaiCookie() async {
    final prefs = await SharedPreferences.getInstance();
    var ckTmp = prefs.getString('eh_cookies');
    var ck = ckTmp ?? '';
    ck = ck
        .split(';')
        .where((cookieKeyVal) => cookieKeyVal.contains('='))
        .join(';');
    if (ck.isEmpty) return;
    ck = ck
        .split(';')
        .where((cookieKeyVal) => !cookieKeyVal.trim().startsWith('sk='))
        .join(';');
    final res = await http.get('https://e-hentai.org', headers: {'Cookie': ck});
    res.headers.forEach((key, value) {
      if (key == 'set-cookie') {
        final firstCookieString = value.split(';')[0];
        final firstCookieKey = firstCookieString
            .substring(0, firstCookieString.indexOf('='))
            .trim();
        final firstCookieValue = firstCookieString
            .substring(
                firstCookieString.indexOf('=') + 1, firstCookieString.length)
            .trim();
        if (firstCookieKey != 'sk') return;
        var ckTmp2 = ck
            .split(';')
            .where((element) => element.trim().isNotEmpty)
            .toList();
        ckTmp2.add('$firstCookieKey=$firstCookieValue');
        ck = ckTmp2.join(';');
      }
    });
    await prefs.setString('eh_cookies', ck);
  }

  static Future<bool> hasIgneousCookie() async {
    final prefs = await SharedPreferences.getInstance();
    final ckTmp = prefs.getString('eh_cookies');
    var ck = ckTmp ?? '';
    if (!ck.contains(';')) return false;
    var has = false;
    ck
        .split(';')
        .where((cookieKeyVal) => cookieKeyVal.trim().isNotEmpty)
        .where((cookieKeyVal) => cookieKeyVal.contains('='))
        .forEach((cookieKeyVal) {
      final cookieKey =
          cookieKeyVal.substring(0, cookieKeyVal.indexOf('=')).trim();
      final cookieVal =
          cookieKeyVal.substring(cookieKeyVal.indexOf('=') + 1).trim();
      if (cookieKey != 'igneous') return;
      if (cookieVal == 'mystery') return;
      if (cookieVal.isEmpty) return;
      has = true;
    });
    return has;
  }

  static Future<bool> hasSkCookie() async {
    final prefs = await SharedPreferences.getInstance();
    final ckTmp = prefs.getString('eh_cookies');
    var ck = ckTmp ?? '';
    if (!ck.contains(';')) return false;
    var has = false;
    ck
        .split(';')
        .where((cookieKeyVal) => cookieKeyVal.trim().isNotEmpty)
        .where((cookieKeyVal) => cookieKeyVal.contains('='))
        .forEach((cookieKeyVal) {
      final cookieKey =
          cookieKeyVal.substring(0, cookieKeyVal.indexOf('=')).trim();
      final cookieVal =
          cookieKeyVal.substring(cookieKeyVal.indexOf('=') + 1).trim();
      if (cookieKey != 'sk') return;
      if (cookieVal.isEmpty) return;
      has = true;
    });
    return has;
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
        break;
      case 'exhentai.org':
        if (exEhashCouldNotFound[id] == true) {
          Logger.warning(
              '[getEHashById] could not found $id`s ehash from $from');
          throw 'EHASH_LOCK';
        }
        break;
      default:
        if (ehEhashCouldNotFound[id] == true &&
            exEhashCouldNotFound[id] == true) {
          Logger.warning('[getEHashById] could not found $id`s ehash');
          throw 'EHASH_LOCK';
        }
        break;
    }
    if (id.isEmpty) throw Error();
    if (ehashLock[id] == true) {
      // Logger.warning('[getEHashById] ${id} is processing');
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
          final url =
              doc.querySelector('a[href*="/g/$id"]')?.attributes['href'] ?? '';
          final foundEhash = Uri.parse(url)
              .path
              .split('/')
              .lastWhere((e) => e.trim().isNotEmpty)
              .trim();
          if (ehash == null && foundEhash.isNotEmpty) {
            if (host.contains('exhentai')) ehashs = exEhashs;
            if (host.contains('e-hentai')) ehashs = ehEhashs;
            ehash = foundEhash;
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
        final searchResponse =
            await ddg.searchProxied('site:e-hentai.org in-url:/g/$id/');
        var foundEncodedUrls = parse(searchResponse.body)
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
        break;
      default:
        ehEhashCouldNotFound[id] = true;
        exEhashCouldNotFound[id] = true;
        break;
    }
    ehashLock[id] = false;
    Logger.warning('[getEHashById] Could not found hash of $id');
    throw 'NOT_FOUND_EHASH';
  }
}
