// This source code is a part of Project Violet.
// Copyright (C) 2020-2021. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/cert/cert_data.dart';
import 'package:violet/cert/cert_util.dart';
import 'package:violet/cert/root.dart';

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
  });

  /*
  for linux 

  git clone https://github.com/abner/quickjs-c-bridge
  cd quickjs-c-bridge
  cmake -S ./linux -B ./build/linux
  cmake --build build/linux
  sudo cp build/linux/libquickjs_c_bridge_plugin.so /usr/lib/libquickjs_c_bridge_plugin.so
  */
  test("JS Simple Test", () async {
    JavascriptRuntime flutterJs;
    flutterJs = getJavascriptRuntime();

    flutterJs.onMessage('fromFlutter', (dynamic args) {
      print(args);
    });

    var tt =
        ''' var galleryinfo = {"title":"Saenai Heroine Series Vol. 8 Saenai Itoko no Ikasekata | 시원찮은 히로인 시리즈 Vol. 8 - 시원찮은 사촌녀의 절정방법","id":"1674850","japanese_title":null,"files":[{"hash":"2474bb809c050c02ba5a4b37ed040861da09986ee949dea4156d6f838089633e","name":"000.jpg","hasavif":1,"height":2023,"width":1403,"haswebp":1},{"width":1403,"haswebp":1,"height":2023,"hasavif":1,"hash":"4c8220585278888d73d648bd66c00885ed688d0ed2339e40d18e308af7a1d26b","name":"001.jpg"},{"hash":"32db83de2ccc13b54bda272f8c07981ca1ab18050fb714705a29d28382757dc1","name":"002.jpg","hasavif":1,"height":2019,"width":1386,"haswebp":1},{"hasavif":1,"name":"003.jpg","hash":"1b212af89f7fbd1aec935095e63a36a103c9f49d22dbc7fa6ce2dda4c1e97858","width":1386,"haswebp":1,"height":2025},{"hasavif":1,"name":"004.jpg","hash":"d7b20d281aa65e47fb73d52ffe9c7d71bd248e85cfb6a8f35b5049971fed1418","width":1399,"haswebp":1,"height":2026},{"hasavif":1,"name":"005.jpg","hash":"e2b0b86cdb83c420328bac6d70b6d4bcb8ceeeb1f4688ca2c9187729279f821b","haswebp":1,"width":1400,"height":2027},{"hasavif":1,"name":"006.jpg","hash":"52f84ea644e7735d6afcd986b2fa4aeeca7276b6f765343872972d84edbf86d8","width":1401,"haswebp":1,"height":2021},{"width":1399,"haswebp":1,"height":2026,"hasavif":1,"hash":"9508c56093d95340c663c3d8fa1740211be0fd2e878b9052ecbb2adf9c3f3997","name":"007.jpg"},{"height":2026,"width":1399,"haswebp":1,"hash":"581665b3d928042f7f904355f43c9b38c2a405ebbdc911f97243aa147be369cc","name":"008.jpg","hasavif":1},{"height":2023,"haswebp":1,"width":1397,"hash":"bde68b146a180455ab0cd123c160165c3a0dcfd2c524ea9ca16a272d88071d13","name":"009.jpg","hasavif":1},{"height":2025,"width":1397,"haswebp":1,"hash":"d822db8dfd1095e979a204e0b3e2143fe1b59b0e9a8a0e7a04ba4e9901fbf2bf","name":"010.jpg","hasavif":1},{"height":2027,"haswebp":1,"width":1397,"name":"011.jpg","hash":"94ef77d00da6e3f5fc482ab4c018989df9cdad2e567b838441ec4859800aac49","hasavif":1},{"height":2022,"width":1399,"haswebp":1,"hash":"fdf029e897334a382713a9d4bec4bc8abc2e430bc21d6c5e21af72a4341a1bf1","name":"012.jpg","hasavif":1},{"hasavif":1,"hash":"a5172b2c0e6980e5fd6f9764269e8cb906d99ee2f9d2173a40d06fba16639ce1","name":"013.jpg","haswebp":1,"width":1397,"height":2024},{"haswebp":1,"width":1401,"height":2025,"hasavif":1,"name":"014.jpg","hash":"de2f45e28157f20d05c8c3386b7bf3dc3299378ec7335bd3b7962c63d35343c4"},{"hasavif":1,"name":"015.jpg","hash":"ff7f5c7b48b06249e49b6c7e70bf096f0f395ea09e9b6c6a89e475f96e709550","width":1399,"haswebp":1,"height":2024},{"haswebp":1,"width":1400,"height":2018,"hasavif":1,"hash":"489b9e6641acd3bb1f0ea90dc1bfc0321ce1102bcf39ef63ed743be9dda6cbb4","name":"016.jpg"},{"hasavif":1,"hash":"d21771beb363d768ac6dcfbcbadc4711b455bee1fe7006f4fff8b7ac21f67485","name":"017.jpg","haswebp":1,"width":1399,"height":2026},{"haswebp":1,"width":1399,"height":2026,"hasavif":1,"hash":"24742a206a65583552bf565628d6edbbaff12d515cc8a5a14d84df723d34b0f2","name":"018.jpg"},{"name":"019.jpg","hash":"0246d0f4197bd3444d3198f9eb1f937c2a871f0a9cfa89f63fb87247c3c30796","hasavif":1,"height":2023,"width":1397,"haswebp":1},{"haswebp":1,"width":1397,"height":2019,"hasavif":1,"name":"020.jpg","hash":"75889324fbeea021944be32e1f60978586557c7ccb87cbb629dde350ca78c67e"},{"hash":"3e0ac4875ad9f8beaf31c3bc5948a03dc1f9074e13de3045abd0749264132de2","name":"021.jpg","hasavif":1,"height":2019,"haswebp":1,"width":1399},{"width":1400,"haswebp":1,"height":2028,"hasavif":1,"name":"022.jpg","hash":"0f7b9c9eb4334521850f53f4a0173128d518fae58671c212e633591efa4b7e90"},{"hasavif":1,"name":"023.jpg","hash":"2aa4f26e8074d40c09c6d86fadb79e6e5db6531c8a3e2179470a671f903f080b","width":1400,"haswebp":1,"height":2025},{"height":2023,"haswebp":1,"width":1399,"hash":"587517ba75af3d9e1b70cd0b4838e27657f551f47dc55b4b96e93d8822fb6db8","name":"024.jpg","hasavif":1},{"height":2024,"haswebp":1,"width":1401,"hash":"8717d7089fd501bc636dab5c1c5786b731f62525b2f45bc98eb71bcbe9644589","name":"025.jpg","hasavif":1},{"height":2025,"width":1387,"haswebp":1,"name":"026.jpg","hash":"2f26992c5ab6d51182b7cb68d8fb328bde4e64123dca08c2cadb63706f0eb130","hasavif":1},{"hash":"0f8d9d2eb475aff2161135ca24a0fc79108b5e5f8a77c35d3cc938fde774b0ca","name":"027.jpg","hasavif":1,"height":2020,"haswebp":1,"width":1389},{"hasavif":1,"name":"028.jpg","hash":"79b5ec0e51de028be832da139077d39b9e2b19ee9bef91772afeb537ecb9566b","width":1403,"haswebp":1,"height":2028},{"hasavif":1,"name":"029.jpg","hash":"9c056fd48cfe0ed99e75b67332dd683d15277c61017040d48a88ce75a92d37ff","haswebp":1,"width":1111,"height":1554},{"name":"030.jpg","hash":"8fe3c5020b18d346cc3e86d12538d52295219378e5343da9ba536d82601d6d6e","hasavif":1,"height":2000,"width":1500,"haswebp":1}],"language_localname":"한국어","date":"2020-07-03 01:07:00-05","type":"doujinshi","language":"korean","tags":[{"female":"1","url":"/tag/female%3Ablowjob-all.html","male":"","tag":"blowjob"},{"female":"1","url":"/tag/female%3Acousin-all.html","male":"","tag":"cousin"},{"tag":"cunnilingus","male":"","female":"1","url":"/tag/female%3Acunnilingus-all.html"},{"url":"/tag/female%3Agokkun-all.html","female":"1","male":"","tag":"gokkun"},{"url":"/tag/female%3Akissing-all.html","female":"1","tag":"kissing","male":""},{"male":"","tag":"nakadashi","female":"1","url":"/tag/female%3Anakadashi-all.html"},{"tag":"schoolgirl uniform","male":"","url":"/tag/female%3Aschoolgirl%20uniform-all.html","female":"1"},{"female":"1","url":"/tag/female%3Asole%20female-all.html","tag":"sole female","male":""},{"male":"","tag":"sweating","female":"1","url":"/tag/female%3Asweating-all.html"},{"tag":"incest","url":"/tag/incest-all.html"},{"url":"/tag/male%3Aglasses-all.html","female":"","tag":"glasses","male":"1"},{"male":"1","tag":"schoolboy uniform","url":"/tag/male%3Aschoolboy%20uniform-all.html","female":""},{"female":"","url":"/tag/male%3Asole%20male-all.html","tag":"sole male","male":"1"},{"tag":"multi-work series","url":"/tag/multi%2Dwork%20series-all.html"}]} ''';

    var x = flutterJs.evaluate('''
      console.log('asdf');
      sendMessage('fromFlutter',  JSON.stringify('tt'));
      function test(ar) {return ar + '3';}
      function create_download_url(id) {
        return "https://ltn.hitomi.la/galleries" + id + ".js";
      }
      function hitomi_get_image_list(id, gg) {
        if (gg.startsWith("<html>")) return null;

        files = JSON.parse(gg.substr(gg.indexOf("=") + 1))["files"];
        number_of_frontends = 3;

        subdomain = String.fromCharCode(
          97 + (id.charCodeAt(id.length - 1) % number_of_frontends)
        );

        btresult = [];
        stresult = [];
        result = [];

        for (var rr of files) {
          hash = rr["hash"];
          postfix = hash.substr(hash.length - 3);
          subdomainx = subdomain;
          if (rr["haswebp"] == 0 || rr["haswebp"] == null) subdomainx = "b";

          x = parseInt(postfix[0] + postfix[1], 16);

          if (!isNaN(x)) {
            var o = 0;
            if (x < 0x7a) o = 1;
            subdomainx = String.fromCharCode(97 + o);
          }

          if (rr["haswebp"] == 0 || rr["haswebp"] == null) {
            result.push(
              `https://\${subdomainx}b.hitomi.la/images/\${postfix[2]}/\${postfix[0]}\${postfix[1]}/\${hash}.\${rr['name'].split('.')[-1]}`
            );
          } else if (hash == "")
            result.push(
              `https://\${subdomainx}a.hitomi.la/webp/\${rr[\'name\']}.webp`
            );
          else if (hash.length < 3)
            result.push(`https://\${subdomainx}a.hitomi.la/webp/\${hash}.webp`);
          else {
            result.push(
              `https://\${subdomainx}a.hitomi.la/webp/\${postfix[2]}/\${postfix[0]}\${postfix[1]}/\${hash}.webp`
            );
          }
          btresult.push(
            `https://tn.hitomi.la/bigtn/\${postfix[2]}/\${postfix[0]}\${postfix[1]}/\${hash}.jpg`
          );
          stresult.push(
            `https://\${subdomainx}tn.hitomi.la/smalltn/\${postfix[2]}/\${postfix[0]}\${postfix[1]}/\${hash}.jpg`
          );
        }

        return JSON.stringify({ btresult: btresult, stresult: stresult, result: result });
      }
    ''');

    // var xx = flutterJs
    //     .evaluate(
    //         "hitomi_get_image_list('12456',\"${tt.replaceAll('"', '\\"')}\")")
    //     .rawResult as Map<dynamic, dynamic>;

    final jResult = flutterJs
        .evaluate(
            "hitomi_get_image_list('12456', \"${tt.replaceAll('"', '\\"')}\")")
        .stringResult;
    final jResultObject = jsonDecode(jResult);

    if (jResultObject is Map<dynamic, dynamic>) {
      print(jResultObject['result']);
    }

    expect(jResult, 'mm3');
  });
}
