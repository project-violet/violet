// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:get/get.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;

class EHSession {
  static EHSession? tryLogin(String id, String pass) {
    return null;
  }
  static Future<void> refreshExhentaiCookie() async {
    final prefs = await SharedPreferences.getInstance();
    var ck_tmp = prefs.getString('eh_cookies');
    var ck = ck_tmp ?? '';
    ck = ck.split(';').where((cookieKeyVal) => cookieKeyVal.contains('=')).join(';');
    if(ck.isEmpty) return;
    ck = ck.split(';').where((cookieKeyVal) => !cookieKeyVal.trim().startsWith('igneous=')).join(';');
    final res = await http.get('https://exhentai.org',headers: { 'Cookie': ck });
    res.headers.forEach((key, value) {
      if(key == 'set-cookie'){
        final firstCookieString = value.split(';')[0];
        final firstCookieKey = firstCookieString.substring(0,firstCookieString.indexOf('=')).trim();
        final firstCookieValue = firstCookieString.substring(firstCookieString.indexOf('=') + 1,firstCookieString.length).trim();
        if(firstCookieKey == 'igneous' && firstCookieValue == 'mystery') return;
        var _ck = ck.split(';').where((element) => element.trim().isNotEmpty).toList();
        _ck.add('${firstCookieKey}=${firstCookieValue}');
        ck = _ck.join(';');
      }
    });
    await prefs.setString('eh_cookies', ck);
  }

  static Future<void> refreshEhentaiCookie() async {
    final prefs = await SharedPreferences.getInstance();
    var ck_tmp = prefs.getString('eh_cookies');
    var ck = ck_tmp ?? '';
    ck = ck.split(';').where((cookieKeyVal) => cookieKeyVal.contains('=')).join(';');
    if(ck.isEmpty) return;
    ck = ck.split(';').where((cookieKeyVal) => !cookieKeyVal.trim().startsWith('sk=')).join(';');
    final res = await http.get('https://e-hentai.org',headers: { 'Cookie': ck });
    res.headers.forEach((key, value) {
      if(key == 'set-cookie'){
        final firstCookieString = value.split(';')[0];
        final firstCookieKey = firstCookieString.substring(0,firstCookieString.indexOf('=')).trim();
        final firstCookieValue = firstCookieString.substring(firstCookieString.indexOf('=') + 1,firstCookieString.length).trim();
        if(firstCookieKey != 'sk') return;
        var _ck = ck.split(';').where((element) => element.trim().isNotEmpty).toList();
        _ck.add('${firstCookieKey}=${firstCookieValue}');
        ck = _ck.join(';');
      }
    });
    await prefs.setString('eh_cookies', ck);
  }

  static Future<bool> hasIgneousCookie() async {
    final prefs = await SharedPreferences.getInstance();
    final ck_tmp = prefs.getString('eh_cookies');
    var ck = ck_tmp ?? '';
    if(!ck.contains(';')) return false;
    var _has = false;
    ck.split(';')
    .where((cookieKeyVal) => cookieKeyVal.trim().isNotEmpty)
    .where((cookieKeyVal) => cookieKeyVal.contains('='))
    .forEach((cookieKeyVal) {
      final cookieKey = cookieKeyVal.substring(0,cookieKeyVal.indexOf('=')).trim();
      final cookieVal = cookieKeyVal.substring(cookieKeyVal.indexOf('=') + 1).trim();
      if(cookieKey != 'igneous') return;
      if(cookieVal == 'mystery') return;
      if(cookieVal.isEmpty) return;
      _has = true;
    });
    return _has;
  }
  static Future<bool> hasSkCookie() async {
    final prefs = await SharedPreferences.getInstance();
    final ck_tmp = prefs.getString('eh_cookies');
    var ck = ck_tmp ?? '';
    if(!ck.contains(';')) return false;
    var _has = false;
    ck.split(';')
    .where((cookieKeyVal) => cookieKeyVal.trim().isNotEmpty)
    .where((cookieKeyVal) => cookieKeyVal.contains('='))
    .forEach((cookieKeyVal) {
      final cookieKey = cookieKeyVal.substring(0,cookieKeyVal.indexOf('=')).trim();
      final cookieVal = cookieKeyVal.substring(cookieKeyVal.indexOf('=') + 1).trim();
      if(cookieKey != 'sk') return;
      if(cookieVal.isEmpty) return;
      _has = true;
    });
    return _has;
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
  static Future<String> getEHashById(String id) async {
    if(id.isEmpty) throw Error();
    String? ehash;
    await Future.forEach(['e-hentai.org','exhentai.org'],(host) async {
      if(ehash != null) return;
      try {
        final list_html = await EHSession.requestString('https://${host}/?next=${(int.parse(id) + 1)}');
        final doc = parse(list_html);
        final _ehash = doc.querySelector('a[href*="/g/${id}"]')?.attributes['href']?.split('/').lastWhere((element) => element.isNotEmpty);
        if(_ehash == null) return;
        if(ehash == null) ehash = _ehash;
      } catch(e,st){
        return;
      }
    });
    if(ehash != null) return ehash ?? '';
    if(ehash == null){
      final search_res = await http.post(
        "https://lite.duckduckgo.com/lite/",
        body: 'q=${('https://e-hentai.org/g/${id}/').replaceAll(':', '%3A').replaceAll('/', '%2F')}&kl=&df=',
        headers: {
          'user-agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0',
          'Content-Type': 'application/x-www-form-urlencoded',
        }
      );
      final search_html = search_res.body;
      final found_url = parse(search_html)
        .querySelector('[href*="/g/${id}/"]')
        ?.attributes['href'];
      ehash = found_url?.split('/').lastWhere((element) => element.isNotEmpty);
    }
    if(ehash != null){
      return ehash ?? '';
    }
    Logger.warning('[getEHashById] Could not found hash of ${id}');
    throw Error();
  }
}
