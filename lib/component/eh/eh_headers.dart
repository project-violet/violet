// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:get/get.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/duckduckgo/search.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;

class EHSession {
  static Map<String,String> ex_ehashs = Map<String,String>();
  static Map<String,String> eh_ehashs = Map<String,String>();
  static Map<String,bool> eh_ehash_could_not_found = Map<String,bool>();
  static Map<String,bool> ex_ehash_could_not_found = Map<String,bool>();
  static Map<String,bool> ehash_lock = Map<String,bool>();
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
  static Future<String> getEHashById(String id,[String? from]) async {
    switch(from){
      case 'e-hentai.org':
        if(eh_ehash_could_not_found[id] == true) {
          Logger.warning('[getEHashById] could not found ${id}`s ehash from ${from}');
          throw 'EHASH_LOCK';
        }
      case 'exhentai.org':
        if(ex_ehash_could_not_found[id] == true) {
          Logger.warning('[getEHashById] could not found ${id}`s ehash from ${from}');
          throw 'EHASH_LOCK';
        }
      default:
        if(eh_ehash_could_not_found[id] == true && ex_ehash_could_not_found == true){
          Logger.warning('[getEHashById] could not found ${id}`s ehash');
          throw 'EHASH_LOCK';
        }
    }
    if(ehash_lock[id] == true){
      // Logger.warning('[getEHashById] ${id} is processing');
      throw 'EHASH_LOCK';
    } else {
      ehash_lock[id] = true;
    }
    if(id.isEmpty) throw Error();
    String? ehash;
    Map<String,String> ehashs = Map<String,String>();
    switch(from){
      case 'e-hentai.org':
        ehashs = eh_ehashs;
        break;
      case 'exhentai.org':
        ehashs = ex_ehashs;
        break;
      default:
        if(from == null){
          ehashs = Map<String,String>();
          ehashs.addAll(ex_ehashs);
          ehashs.addAll(eh_ehashs);
        }
        break;
    }
    if(ehashs[id]?.isNotEmpty ?? false){
      ehash_lock[id] = false;
      return ehashs[id] ?? '';
    }
    try {
    await Future.forEach([...(from == null ? ['e-hentai.org','exhentai.org'] : [from])],(host) async { // next?${id + 1} search for {e-/ex}hentai.org
      if(ehash != null) return;
      try {
        final list_html = await EHSession.requestString('https://${host}/?next=${(int.parse(id) + 1)}');
        final doc = parse(list_html);
        final _url = doc.querySelector('a[href*="/g/${id}"]')?.attributes['href'] ?? '';
        final _ehash = Uri.parse(_url).path.split('/').lastWhere((e) => e.trim().isNotEmpty).trim();
        if(ehash == null && _ehash.isNotEmpty) {
          if(host.contains('exhentai')) ehashs = ex_ehashs;
          if(host.contains('e-hentai')) ehashs = eh_ehashs;
          ehash = _ehash;
        }
      } catch(e,st){
      }
    });
    } catch(_){}
    if(ehash != null) {
      ehash_lock[id] = false;
      return (ehashs[id] = (ehash ?? ''));
    }
    if(ehash == null && (from?.contains('e-hentai.org') ?? true)){ // duckduckgo search (only for search e-hentai.org)
      ehashs = eh_ehashs;
      try{
        final ddg = DuckDuckGoSearch();
        final search_res = await ddg.searchProxied('site:e-hentai.org in-url:/g/${id}/');
        final search_html = search_res.body;
        var found_encoded_urls = parse(search_res.body)
          .querySelectorAll('a[href*="${Uri.encodeComponent('/g/${id}')}"]')
          .map((encoded_url) => encoded_url.attributes['href']?.trim() ?? '')
          .where((encoded_url) => encoded_url.trim().isNotEmpty);
        var url = '';
        found_encoded_urls
          ?.map((url) => Uri.parse(url ?? '').queryParameters)
          ?.forEach((element){
            element.forEach((key, value) {
              if(value.contains('/g/${id}/')){
                url = value;
              }
            });
          });
        ehashs[id] = ehash = url.split('/').lastWhere((e) => e.isNotEmpty);
      }catch(_){}
    }
    if(ehash != null){
      ehash_lock[id] = false;
      return ehash ?? '';
    }
    switch(from){
      case 'e-hentai.org':
        eh_ehash_could_not_found[id] = true;
        break;
      case 'exhentai.org':
        ex_ehash_could_not_found[id] = true;
      default:
        eh_ehash_could_not_found[id] = true;
        ex_ehash_could_not_found[id] = true;
    }
    ehash_lock[id] = false;
    Logger.warning('[getEHashById] Could not found hash of ${id}');
    throw 'NOT_FOUND_EHASH';
  }
}
