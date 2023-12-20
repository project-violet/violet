import 'dart:convert';
import 'dart:io';

import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/database/user/cookie.dart';
import 'package:violet/log/log.dart';
import 'package:violet/settings/path.dart';
import 'package:violet/settings/settings.dart';

class CookieReader {
  static Future<void> getCookieFirefoxLinux() async {
    final find_path = '${(await DefaultPathProvider.getHomeDirectory())}';
    var db_path_list = [];
    try{
    var process = await Process.start("find", [
      '${find_path}','-name',"cookies.sqlite",'-type','f'
    ]);

      await process.stdout
        .transform(utf8.decoder)
        .forEach((db_path){
          Logger.info(db_path);
          if(db_path.isNotEmpty) db_path_list.add(db_path);
        });
    } catch(e,st){
      Logger.error("$e\n"
        "$st");
    }
    db_path_list = (db_path_list.join('\n').split('\n')).where((String element) => (element.isNotEmpty)).toList();

    for(final db_path in db_path_list){
      final tmp_db_path = '${(await DefaultPathProvider.getBaseDirectory())}/cookies.db.tmp';
      Logger.info(db_path);
      if((await File('${tmp_db_path}').exists())){
        await File('${tmp_db_path}').delete();
      }
      final db_path_find_result = await Process.run("cp", [
        '${db_path}','${tmp_db_path}'
      ]);
      final result = await (await CookiesManager.getInstance(tmp_db_path))
        .query("SELECT * FROM moz_cookies WHERE host LIKE '%e-hentai.org'");
      var cookie_str = '';
      result.forEach((row) {
        var name,value;
        row.entries.forEach((col) {
          switch(col.key){
            case 'name': name = col.value; break;
            case 'value': value = col.value; break;
          }
        });
        cookie_str += '${name}=${value}; ';
      });
      await (await MultiPreferences.getInstance())
        .setString('eh_cookies', cookie_str);
      var login_result_html = await EHSession.requestRedirect('https://e-hentai.org/favorites.php');
      if(login_result_html != null){
        await (await MultiPreferences.getInstance())
          .setString('eh_cookies', '');
        continue;
      }
      if((await File('${tmp_db_path}').exists())){
        await File('${tmp_db_path}').delete();
      }
      break;
    }
  }
}