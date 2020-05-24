
import 'dart:convert';

import 'package:http/http.dart' as http;

class HitomiManager {

  static Future<List<String>> getImageList(String id) async {
    var gg = await http.get('https://ltn.hitomi.la/galleries/$id.js');
    var urls = gg.body;
    var files = jsonDecode(urls.substring(urls.indexOf('=') + 1)).cast<String, dynamic>()['files'];
    const number_of_frontends = 3;
    final subdomain = String.fromCharCode(97 + (id[id.length - 1].codeUnitAt(0) % number_of_frontends));

    var result = List<String>();
    for (var row in files) {
      var rr = row.cast<String, String>();
      var hash = rr['hash'] as String;
      if (rr['hashwebp'] == 0) {
        var postfix = hash.substring(hash.length - 3);
        result.add('https://${subdomain}a.hitomi.la/images/${postfix[2]}/${postfix[0]}${postfix[1]}/$hash.${(rr['hash'] as String).split('.').last}');
      }
      else if (hash == "")
        result.add('https://${subdomain}a.hitomi.la/webp/${rr['name'] as String}.webp');
      else if (hash.length < 3)
        result.add('https://${subdomain}a.hitomi.la/webp/$hash.webp');
      else {
        var postfix = hash.substring(hash.length - 3); 
        result.add('https://${subdomain}a.hitomi.la/images/${postfix[2]}/${postfix[0]}${postfix[1]}/$hash.webp');
      }
    }
    return result;
  }

}