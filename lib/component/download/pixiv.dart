// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

// Reference https://github.com/rollrat/downloader/blob/master/Koromo_Copy.Framework/Extractor/PixivExtractor.cs
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/downloadable.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

class PixivAPI {
  static Future<String> getAccessToken(String username, String password) async {
    const client_id = "MOBrBDS8blbauoSck0ZfDbtuzpyT";
    const client_secret = "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj";
    const hash_secret =
        "28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c";
    var localTime =
        DateFormat('yyyy-MM-ddTHH:MM:ss+00:00').format(DateTime.now().toUtc());

    var result =
        await http.post('https://oauth.secure.pixiv.net/auth/token', headers: {
      'UserAgent': 'PixivAndroidApp/5.0.64 (Android 6.0)',
      'Referer': 'http://www.pixiv.net/',
      'X-Client-Time': localTime,
      'X-Client-Hash': md5
          .convert(utf8.encode(localTime + hash_secret))
          .toString()
          .toLowerCase(),
    }, body: {
      'grant_type': 'password',
      'username': username,
      'password': password,
      'get_secure_url': '1',
      'client_id': client_id,
      'client_secret': client_secret
    });

    var decode = jsonDecode(result.body)['response'];
    if (decode == null) return null;

    return decode['access_token'].toString();
  }

  static Future<Map<String, dynamic>> getUser(
      String accessToken, int authorId) async {
    var url = "https://public-api.secure.pixiv.net/v1/users/" +
        authorId.toString() +
        ".json";

    var param = {
      "profile_image_sizes": "px_170x170,px_50x50",
      "image_sizes": "px_128x128,small,medium,large,px_480mw",
      "include_stats": "1",
      "include_profile": "1",
      "include_workspace": "1",
      "include_contacts": "1",
    };

    var result = await http.get(
        url +
            '?' +
            param.entries.toList().map((e) => '${e.key}=${e.value}').join('&'),
        headers: {
          'Referer': 'http://spapi.pixiv.net/',
          'UserAgent': 'PixivIOSApp/5.8.0',
          'Authorization': 'Bearer ' + accessToken,
        });

    return jsonDecode(utf8.decode(result.bodyBytes))['response'][0];
  }

  static Future<List<dynamic>> getUserWorks(String accessToken, int authorId,
      [int page = 1,
      int perPage = 30,
      String publicity = "public",
      bool includeSanityLevel = true]) async {
    var url = "https://public-api.secure.pixiv.net/v1/users/" +
        authorId.toString() +
        "/works.json";

    var param = {
      "page": page.toString(),
      "per_page": perPage.toString(),
      "publicity": publicity,
      "include_stats": "1",
      "include_sanity_level": includeSanityLevel ? 1 : 0,
      "image_sizes": "px_128x128,small,medium,large,px_480mw",
      "profile_image_sizes": "px_170x170,px_50x50",
    };

    var result = await http.get(
        url +
            '?' +
            param.entries.toList().map((e) => '${e.key}=${e.value}').join('&'),
        headers: {
          'Referer': 'http://spapi.pixiv.net/',
          'UserAgent': 'PixivIOSApp/5.8.0',
          'Authorization': 'Bearer ' + accessToken,
        });

    return jsonDecode(result.body)['response'];
  }

  static Future<List<dynamic>> getWorks(
      String accessToken, int illustId) async {
    var url = "https://public-api.secure.pixiv.net/v1/works/" +
        illustId.toString() +
        ".json";

    var param = {
      "image_sizes": "px_128x128,small,medium,large,px_480mw",
      "profile_image_sizes": "px_170x170,px_50x50",
      "include_stats": "true"
    };

    var result = await http.get(
        url +
            '?' +
            param.entries.toList().map((e) => '${e.key}=${e.value}').join('&'),
        headers: {
          'Referer': 'http://spapi.pixiv.net/',
          'UserAgent': 'PixivIOSApp/5.8.0',
          'Authorization': 'Bearer ' + accessToken,
        });

    return jsonDecode(result.body)['response'];
  }

  static Future<dynamic> getUgoira(String accessToken, String illustId) async {
    var url = "https://app-api.pixiv.net/v1/ugoira/metadata";

    var param = {
      "illust_id": illustId,
    };

    var result = await http.get(
        url +
            '?' +
            param.entries.toList().map((e) => '${e.key}=${e.value}').join('&'),
        headers: {
          'Referer': 'http://spapi.pixiv.net/',
          'UserAgent': 'PixivIOSApp/5.8.0',
          'Authorization': 'Bearer ' + accessToken,
        });

    return jsonDecode(result.body)['ugoira_metadata'];
  }
}

class PixivManager extends Downloadable {
  RegExp urlMatcher;
  String accessToken;

  PixivManager() {
    urlMatcher = RegExp(
        r'^https?://(www\.)?pixiv\.net/(member(?:_illust)?\.php\?id\=|artworks/|users/)(?<id>.*?)/?$');
  }

  @override
  String fav() {
    return 'https://www.pixiv.net/favicon.ico';
  }

  @override
  bool acceptURL(String url) {
    return urlMatcher.stringMatch(url) == url;
  }

  @override
  String defaultFormat() {
    return "%(extractor)s/%(artist)s (%(account)s)/%(file)s.%(ext)s";
  }

  @override
  Future<List<DownloadTask>> createTask(
      String url, GeneralDownloadProgress gdp) async {
    var match = urlMatcher.allMatches(url);
    if (match.first[2].startsWith('member') ||
        match.first[2].startsWith('users')) {
      var user = await PixivAPI.getUser(
          accessToken, int.parse(match.first.namedGroup('id')));
      var works = await PixivAPI.getUserWorks(
          accessToken, int.parse(match.first.namedGroup('id')), 1, 10000000);

      if (user == null ||
          user.length == 0 ||
          works == null ||
          works.length == 0) return null;

      if (gdp.simpleInfoCallback != null)
        gdp.simpleInfoCallback.call('${user['name']} (${user['account']})');
      if (gdp.thumbnailCallback != null)
        gdp.thumbnailCallback.call(user['profile_image_urls']['px_170x170'],
            jsonEncode({'Referer': url}));

      var result = List<DownloadTask>();
      for (int i = 0; i < works.length; i++) {
        var e = works[i];
        if (e['page_count'] > 1) {
          var x = await PixivAPI.getWorks(accessToken, e['id']);

          x.forEach((element) {
            element['metadata']['pages'].forEach((e) {
              result.add(
                DownloadTask(
                  url: e['image_urls']['large'],
                  filename: e['image_urls']['large'].split('/').last,
                  referer: url,
                  format: FileNameFormat(
                    artist: user['name'],
                    account: user['account'],
                    id: user['id'].toString(),
                    filenameWithoutExtension: path.basenameWithoutExtension(
                        e['image_urls']['large'].split('/').last),
                    extension: path
                        .extension(e['image_urls']['large'].split('/').last)
                        .replaceAll(".", ""),
                    extractor: 'pixiv',
                  ),
                ),
              );
            });
          });
        }

        if (e['type'] == null || e['type'] == 'illustration') {
          result.add(
            DownloadTask(
              url: e['image_urls']['large'],
              filename: e['image_urls']['large'].split('/').last,
              referer: url,
              format: FileNameFormat(
                artist: user['name'],
                account: user['account'],
                id: user['id'].toString(),
                filenameWithoutExtension: path.basenameWithoutExtension(
                    e['image_urls']['large'].split('/').last),
                extension: path
                    .extension(e['image_urls']['large'].split('/').last)
                    .replaceAll(".", ""),
                extractor: 'pixiv',
              ),
            ),
          );
        } else if (e['type'] == 'ugoira') {
          // TODO: Pixiv Ugoira
        }

        gdp.progressCallback.call(result.length, 0);
      }
      return result;
    }
    return null;
  }

  @override
  Future<void> setSession(String id, String pwd) async {
    accessToken = await PixivAPI.getAccessToken(id, pwd);
  }

  @override
  bool loginRequire() {
    return true;
  }

  @override
  String name() {
    return 'Pixiv';
  }

  @override
  bool logined() {
    return !(accessToken == null || accessToken.length == 0);
  }

  @override
  Future<bool> tryLogin() async {
    var id = (await SharedPreferences.getInstance()).getString('pixiv_id');
    var pwd = (await SharedPreferences.getInstance()).getString('pixiv_pwd');
    if (id == null || pwd == null || id == '' || pwd == '') return false;
    await setSession(id, pwd);
    return logined();
  }
}
