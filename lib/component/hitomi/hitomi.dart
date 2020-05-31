import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';

class HitomiManager {
  static Future<List<String>> getImageList(String id) async {
    var gg = await http.get('https://ltn.hitomi.la/galleries/$id.js');
    var urls = gg.body;
    var files = jsonDecode(urls.substring(urls.indexOf('=') + 1))
        .cast<String, dynamic>()['files'];
    const number_of_frontends = 3;
    final subdomain = String.fromCharCode(
        97 + (id[id.length - 1].codeUnitAt(0) % number_of_frontends));

    var result = List<String>();
    for (var row in files) {
      var rr = row.cast<String, String>();
      var hash = rr['hash'] as String;
      if (rr['hashwebp'] == 0) {
        var postfix = hash.substring(hash.length - 3);
        result.add(
            'https://${subdomain}a.hitomi.la/images/${postfix[2]}/${postfix[0]}${postfix[1]}/$hash.${(rr['hash'] as String).split('.').last}');
      } else if (hash == "")
        result.add(
            'https://${subdomain}a.hitomi.la/webp/${rr['name'] as String}.webp');
      else if (hash.length < 3)
        result.add('https://${subdomain}a.hitomi.la/webp/$hash.webp');
      else {
        var postfix = hash.substring(hash.length - 3);
        result.add(
            'https://${subdomain}a.hitomi.la/webp/${postfix[2]}/${postfix[0]}${postfix[1]}/$hash.webp');
      }
    }
    return result;
  }

  static Map<String, Map<String, int>> tagmap;
  static Future<List<Tuple3<String, String, int>>> queryAutoComplete(
      String prefix) async {
    if (tagmap == null) {
      final directory = await getExternalStorageDirectory();
      final path = File('${directory.path}/index.json');
      final text = path.readAsStringSync();
      tagmap = jsonDecode(text);
    }

    prefix = prefix.toLowerCase().replaceAll('_', ' ');

    if (prefix.contains(':')) {
      final opp = prefix.split(':')[0];
      var pp = opp;

      if (pp == 'female' || pp == 'male' || pp == 'tag')
        pp = 'tags';
      else if (pp == 'lang')
        pp = 'languages';
      else if (pp == 'artist')
        pp = 'aritsts';
      else if (pp == 'group')
        pp = 'groups';
      else if (pp == 'uploader')
        pp = 'uploaders';
      else if (pp == 'type') pp = 'types';

      var results = new List<Tuple3<String, String, int>>();
      if (!tagmap.containsKey(pp)) return results;

      final ch = tagmap[pp];
      if (opp == 'female' || opp == 'male') {
        ch.forEach((key, value) {
          if (key.toLowerCase().startsWith(prefix))
            results.add(Tuple3<String, String, int>(opp, key, value));
        });
      } else {
        final po = prefix.split(':')[1];

        ch.forEach((key, value) {
          if (key.toLowerCase().startsWith(po))
            results.add(Tuple3<String, String, int>(pp, key, value));
        });
      }
      results.sort((a, b) => b.item2.compareTo(a.item2));
      return results;
    } else {
      var results = new List<Tuple3<String, String, int>>();
      tagmap.forEach((key1, value) {
        if (key1 == 'tags') {
          value.forEach((key2, value2) {
            if (key2.contains(':')) {
              if (key2.split(':')[1].startsWith(prefix))
                results.add(Tuple3<String, String, int>(
                    key2.split(':')[0], key2, value2));
            } else if (key2.startsWith(prefix)) {
              if (key2.contains(':'))
                results.add(Tuple3<String, String, int>(
                    key2.split(':')[0], key2, value2));
              else
                results.add(Tuple3<String, String, int>('tags', key2, value2));
            }
          });
        } else {
          value.forEach((key2, value2) {
            if (key2.toLowerCase().startsWith(prefix))
              results.add(Tuple3<String, String, int>(key1, key2, value2));
          });
        }
      });
      return results;
    }
  }
}
