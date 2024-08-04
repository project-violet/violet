// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

// ignore_for_file: unnecessary_string_escapes

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_test/flutter_test.dart';

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
  test('JS Simple Test', () async {
    JavascriptRuntime flutterJs;
    flutterJs = getJavascriptRuntime();

    flutterJs.onMessage('fromFlutter', (dynamic args) {
      print(args);
    });

    // var tt =
    // ''' var galleryinfo = {"title":"Saenai Heroine Series Vol. 8 Saenai Itoko no Ikasekata | 시원찮은 히로인 시리즈 Vol. 8 - 시원찮은 사촌녀의 절정방법","id":"1674850","japanese_title":null,"files":[{"hash":"2474bb809c050c02ba5a4b37ed040861da09986ee949dea4156d6f838089633e","name":"000.jpg","hasavif":1,"height":2023,"width":1403,"haswebp":1},{"width":1403,"haswebp":1,"height":2023,"hasavif":1,"hash":"4c8220585278888d73d648bd66c00885ed688d0ed2339e40d18e308af7a1d26b","name":"001.jpg"},{"hash":"32db83de2ccc13b54bda272f8c07981ca1ab18050fb714705a29d28382757dc1","name":"002.jpg","hasavif":1,"height":2019,"width":1386,"haswebp":1},{"hasavif":1,"name":"003.jpg","hash":"1b212af89f7fbd1aec935095e63a36a103c9f49d22dbc7fa6ce2dda4c1e97858","width":1386,"haswebp":1,"height":2025},{"hasavif":1,"name":"004.jpg","hash":"d7b20d281aa65e47fb73d52ffe9c7d71bd248e85cfb6a8f35b5049971fed1418","width":1399,"haswebp":1,"height":2026},{"hasavif":1,"name":"005.jpg","hash":"e2b0b86cdb83c420328bac6d70b6d4bcb8ceeeb1f4688ca2c9187729279f821b","haswebp":1,"width":1400,"height":2027},{"hasavif":1,"name":"006.jpg","hash":"52f84ea644e7735d6afcd986b2fa4aeeca7276b6f765343872972d84edbf86d8","width":1401,"haswebp":1,"height":2021},{"width":1399,"haswebp":1,"height":2026,"hasavif":1,"hash":"9508c56093d95340c663c3d8fa1740211be0fd2e878b9052ecbb2adf9c3f3997","name":"007.jpg"},{"height":2026,"width":1399,"haswebp":1,"hash":"581665b3d928042f7f904355f43c9b38c2a405ebbdc911f97243aa147be369cc","name":"008.jpg","hasavif":1},{"height":2023,"haswebp":1,"width":1397,"hash":"bde68b146a180455ab0cd123c160165c3a0dcfd2c524ea9ca16a272d88071d13","name":"009.jpg","hasavif":1},{"height":2025,"width":1397,"haswebp":1,"hash":"d822db8dfd1095e979a204e0b3e2143fe1b59b0e9a8a0e7a04ba4e9901fbf2bf","name":"010.jpg","hasavif":1},{"height":2027,"haswebp":1,"width":1397,"name":"011.jpg","hash":"94ef77d00da6e3f5fc482ab4c018989df9cdad2e567b838441ec4859800aac49","hasavif":1},{"height":2022,"width":1399,"haswebp":1,"hash":"fdf029e897334a382713a9d4bec4bc8abc2e430bc21d6c5e21af72a4341a1bf1","name":"012.jpg","hasavif":1},{"hasavif":1,"hash":"a5172b2c0e6980e5fd6f9764269e8cb906d99ee2f9d2173a40d06fba16639ce1","name":"013.jpg","haswebp":1,"width":1397,"height":2024},{"haswebp":1,"width":1401,"height":2025,"hasavif":1,"name":"014.jpg","hash":"de2f45e28157f20d05c8c3386b7bf3dc3299378ec7335bd3b7962c63d35343c4"},{"hasavif":1,"name":"015.jpg","hash":"ff7f5c7b48b06249e49b6c7e70bf096f0f395ea09e9b6c6a89e475f96e709550","width":1399,"haswebp":1,"height":2024},{"haswebp":1,"width":1400,"height":2018,"hasavif":1,"hash":"489b9e6641acd3bb1f0ea90dc1bfc0321ce1102bcf39ef63ed743be9dda6cbb4","name":"016.jpg"},{"hasavif":1,"hash":"d21771beb363d768ac6dcfbcbadc4711b455bee1fe7006f4fff8b7ac21f67485","name":"017.jpg","haswebp":1,"width":1399,"height":2026},{"haswebp":1,"width":1399,"height":2026,"hasavif":1,"hash":"24742a206a65583552bf565628d6edbbaff12d515cc8a5a14d84df723d34b0f2","name":"018.jpg"},{"name":"019.jpg","hash":"0246d0f4197bd3444d3198f9eb1f937c2a871f0a9cfa89f63fb87247c3c30796","hasavif":1,"height":2023,"width":1397,"haswebp":1},{"haswebp":1,"width":1397,"height":2019,"hasavif":1,"name":"020.jpg","hash":"75889324fbeea021944be32e1f60978586557c7ccb87cbb629dde350ca78c67e"},{"hash":"3e0ac4875ad9f8beaf31c3bc5948a03dc1f9074e13de3045abd0749264132de2","name":"021.jpg","hasavif":1,"height":2019,"haswebp":1,"width":1399},{"width":1400,"haswebp":1,"height":2028,"hasavif":1,"name":"022.jpg","hash":"0f7b9c9eb4334521850f53f4a0173128d518fae58671c212e633591efa4b7e90"},{"hasavif":1,"name":"023.jpg","hash":"2aa4f26e8074d40c09c6d86fadb79e6e5db6531c8a3e2179470a671f903f080b","width":1400,"haswebp":1,"height":2025},{"height":2023,"haswebp":1,"width":1399,"hash":"587517ba75af3d9e1b70cd0b4838e27657f551f47dc55b4b96e93d8822fb6db8","name":"024.jpg","hasavif":1},{"height":2024,"haswebp":1,"width":1401,"hash":"8717d7089fd501bc636dab5c1c5786b731f62525b2f45bc98eb71bcbe9644589","name":"025.jpg","hasavif":1},{"height":2025,"width":1387,"haswebp":1,"name":"026.jpg","hash":"2f26992c5ab6d51182b7cb68d8fb328bde4e64123dca08c2cadb63706f0eb130","hasavif":1},{"hash":"0f8d9d2eb475aff2161135ca24a0fc79108b5e5f8a77c35d3cc938fde774b0ca","name":"027.jpg","hasavif":1,"height":2020,"haswebp":1,"width":1389},{"hasavif":1,"name":"028.jpg","hash":"79b5ec0e51de028be832da139077d39b9e2b19ee9bef91772afeb537ecb9566b","width":1403,"haswebp":1,"height":2028},{"hasavif":1,"name":"029.jpg","hash":"9c056fd48cfe0ed99e75b67332dd683d15277c61017040d48a88ce75a92d37ff","haswebp":1,"width":1111,"height":1554},{"name":"030.jpg","hash":"8fe3c5020b18d346cc3e86d12538d52295219378e5343da9ba536d82601d6d6e","hasavif":1,"height":2000,"width":1500,"haswebp":1}],"language_localname":"한국어","date":"2020-07-03 01:07:00-05","type":"doujinshi","language":"korean","tags":[{"female":"1","url":"/tag/female%3Ablowjob-all.html","male":"","tag":"blowjob"},{"female":"1","url":"/tag/female%3Acousin-all.html","male":"","tag":"cousin"},{"tag":"cunnilingus","male":"","female":"1","url":"/tag/female%3Acunnilingus-all.html"},{"url":"/tag/female%3Agokkun-all.html","female":"1","male":"","tag":"gokkun"},{"url":"/tag/female%3Akissing-all.html","female":"1","tag":"kissing","male":""},{"male":"","tag":"nakadashi","female":"1","url":"/tag/female%3Anakadashi-all.html"},{"tag":"schoolgirl uniform","male":"","url":"/tag/female%3Aschoolgirl%20uniform-all.html","female":"1"},{"female":"1","url":"/tag/female%3Asole%20female-all.html","tag":"sole female","male":""},{"male":"","tag":"sweating","female":"1","url":"/tag/female%3Asweating-all.html"},{"tag":"incest","url":"/tag/incest-all.html"},{"url":"/tag/male%3Aglasses-all.html","female":"","tag":"glasses","male":"1"},{"male":"1","tag":"schoolboy uniform","url":"/tag/male%3Aschoolboy%20uniform-all.html","female":""},{"female":"","url":"/tag/male%3Asole%20male-all.html","tag":"sole male","male":"1"},{"tag":"multi-work series","url":"/tag/multi%2Dwork%20series-all.html"}]} ''';

    /*
    var tt =
        ''' var galleryinfo = {"tags":[{"female":"1","male":"","url":"/tag/female%3Ablowjob-all.html","tag":"blowjob"},{"tag":"loli","female":"1","url":"/tag/female%3Aloli-all.html","male":""},{"url":"/tag/female%3Anakadashi-all.html","male":"","female":"1","tag":"nakadashi"},{"male":"","url":"/tag/female%3Asole%20female-all.html","female":"1","tag":"sole female"},{"tag":"glasses","female":"","male":"1","url":"/tag/male%3Aglasses-all.html"},{"tag":"sole male","female":"","male":"1","url":"/tag/male%3Asole%20male-all.html"}],"files":[{"hash":"4cff9f13340a542c985fc6c1ad3b8e50fdef01347186bbe1b3df9b2a4112d551","height":2880,"width":2040,"hasavif":0,"haswebp":1,"name":"01.jpg"},{"name":"02.jpg","haswebp":1,"hasavif":0,"width":2040,"height":2880,"hash":"b3a45a6da59be2d072b153e7025e8ff9384426e76e626b157cd324b4683f85bf"},{"hash":"61316fc635291d84b2be366e74ad31256ab3e02ec656beda19d0140edd466d58","height":2880,"hasavif":0,"width":2040,"haswebp":1,"name":"03.jpg"},{"hash":"b0974e5486ee72cc2436cc72d67b35a3456c33f2e5785a206ea527f31ac05861","height":2880,"width":2040,"hasavif":0,"haswebp":1,"name":"04.jpg"},{"hash":"320d9fb0db0160598f8f6793f63b91d701edae3d63246b1ff513e8abe2fdfd8c","height":2880,"hasavif":1,"width":2040,"haswebp":1,"name":"05.jpg"},{"hash":"e870fb14d20b30dc69fceff28044ab6e068cf9956eac978d98038cbb1ca5247e","height":2880,"hasavif":0,"width":2040,"name":"06.jpg","haswebp":1},{"haswebp":1,"name":"07.jpg","hasavif":0,"width":2040,"height":2880,"hash":"28e9a908e5577d21c054f85c04f87cb137202464ffc619f10da22b92d66cc0f2"},{"hash":"9e7fdd522b3912856a9403816d4590540c66a456fc9e8362121cf1bf29acfb01","height":2880,"width":2040,"hasavif":0,"haswebp":1,"name":"08.jpg"},{"name":"09.jpg","haswebp":1,"width":2040,"hasavif":0,"height":2880,"hash":"48246dabd043366828f6ca36df3b0f8df67094ac8101c9a85027a547ecda1aa9"},{"name":"10.jpg","haswebp":1,"width":2040,"hasavif":0,"height":2880,"hash":"54cfc71b4ffe5703583219d40b26c82f637244368f0e4cc7c09389df37f8c776"},{"width":2040,"hasavif":0,"haswebp":1,"name":"11.jpg","hash":"0dee45ba612e8bf24523c00b86e92c556efc6ca3651d7d4ee266ee588eabb4a2","height":2880},{"height":2880,"hash":"2debbe3e929ef8d5cdd1ccf2ceaf2002a0706c2c6c2a566a9b82c1ade95703db","haswebp":1,"name":"12.jpg","hasavif":0,"width":2040},{"hash":"8eeaa145756d63f8cd1665ce219fdeb52f782a84170b4ea29a5bb27f2bbb6a89","height":2880,"width":2040,"hasavif":0,"haswebp":1,"name":"13.jpg"},{"width":2040,"hasavif":0,"name":"14.jpg","haswebp":1,"hash":"275926f3b9f4a80d6b909d805dfdecb9c0b067ca2fc3d5462f00b06281ee02f7","height":2880},{"height":2880,"hash":"aa7ab53ca18cdf5d3ca79220bf1fe48b341f50b9be5d86ca4b71f60b31adac54","name":"15.jpg","haswebp":1,"width":2040,"hasavif":0},{"hasavif":0,"width":2040,"haswebp":1,"name":"16.jpg","hash":"534c346fb85e71a1dddee5f5defcc31712e3d427242fa528cda53c47f12cb4c8","height":2880},{"hash":"5ae1d887a8d5880133b0f522d176de3e079acef28a24f920e6baa31d71895248","height":2880,"width":2040,"hasavif":0,"haswebp":1,"name":"17.jpg"},{"width":2040,"hasavif":0,"name":"18.jpg","haswebp":1,"hash":"3738c0253b597c5e14607dfd4b71c58fbbc27b0540d8f6b41c5bcc4eb289f875","height":2880},{"hash":"8d6fcbc24aac138ee172ee7b83a45e6c2a6aff0f51de3adef124d79bf14d7c2e","height":2880,"width":2040,"hasavif":0,"haswebp":1,"name":"19.jpg"},{"hasavif":0,"width":2040,"haswebp":1,"name":"20.jpg","hash":"94b1a2bb904803cda91ec78e4e4f3da955de27519e2af034ae0c1f89d64212bf","height":2880},{"haswebp":1,"name":"21.jpg","hasavif":0,"width":2040,"height":2880,"hash":"06320d025f11a5b813c576602f34f0fa5a26152a349700745d739a5dc66451b8"},{"width":2040,"hasavif":0,"name":"22.jpg","haswebp":1,"hash":"0d07299aa402e3b5cdc38615a5f917c49b8cee925af169107ced5c0d48748ef1","height":2880},{"width":2040,"hasavif":0,"name":"23.jpg","haswebp":1,"hash":"6e4e87e21009802e81da7aa479b8fb0056b0d4b7b55e157393ddad83dd64522d","height":2880},{"height":2880,"hash":"a3a0680751106458e3bcd6fe74bc94ed892e4310dc45763946fa2dfb75b0c27f","haswebp":1,"name":"24.jpg","hasavif":0,"width":2040},{"haswebp":1,"name":"25.jpg","width":2040,"hasavif":0,"height":2880,"hash":"a462a19ca22eb7e76338080f244f13ff76caee385ea66bcb60630bc0f21ce05c"},{"haswebp":1,"name":"26.jpg","hasavif":0,"width":2040,"height":2880,"hash":"79fb923c77c9192a38d921f578e25da4e00aa1bba7c81c7c7d3babbb47634dad"},{"hash":"e6efe443e09d6dd6dedff339173683b83db9d15ec3d49dfdc106e00e537ad007","height":2880,"hasavif":0,"width":2040,"name":"27.jpg","haswebp":1},{"hasavif":0,"width":2040,"haswebp":1,"name":"28.jpg","hash":"829f08ab8417a89d8d2595b05341f272f3fc54cc8fbfc3b1ee22438d41801daf","height":2880},{"hash":"9c86aa7e40f0d9755c77eaa0d1cf5d82e6170cf8037ceb8f56babff9a2480d90","height":2880,"hasavif":0,"width":2040,"haswebp":1,"name":"29.jpg"},{"hasavif":0,"width":2040,"haswebp":1,"name":"30.jpg","hash":"9c8917eabd8f739fa63f4c046951d25cdaf3a53a094b66914b875b3b4ebae35c","height":2880},{"name":"31.jpg","haswebp":1,"width":2040,"hasavif":0,"height":2880,"hash":"830edfd91d84a95b970ffb753d99e2878800085843b767317d02d7b2f1d3723a"},{"hash":"579cc2298708a13228cc33d93fd2511b13862352dc440e6f5d2fee3fb025fa9d","height":2880,"hasavif":0,"width":2040,"name":"32.jpg","haswebp":1},{"hash":"b01a0d8221b5596261c38315d20a745c5e949e9f3d055f382295807217952363","height":2880,"width":2040,"hasavif":0,"haswebp":1,"name":"33.jpg"},{"height":2880,"hash":"477cf44dd8e20b484a66c4fc112cc8eb3fff5c94d611ac9599170536ca33eef9","name":"34.jpg","haswebp":1,"hasavif":0,"width":2040},{"height":2880,"hash":"22836eb14d8c21dd416c217da03c87d68b24a13bb1a4fda20c0eaf788260ba28","name":"35.jpg","haswebp":1,"hasavif":0,"width":2040},{"hasavif":0,"width":2040,"haswebp":1,"name":"36.jpg","hash":"b0c10bd9080d9c1f0d0690ad83268ac9a94bb105b7cdff2eeff3d7818bc693aa","height":2880},{"width":2040,"hasavif":0,"name":"37.jpg","haswebp":1,"hash":"83c28935e4dd155008e5822c47fc5f0d06e59caabedffbb8da16c64f0a2e0f6e","height":2880},{"haswebp":1,"name":"38.jpg","width":2040,"hasavif":0,"height":2880,"hash":"dd60dfd72535a1902900bca11f6db91fd8ee2702452c9d2977eb33ee23c14ab8"},{"width":2040,"hasavif":0,"name":"39.jpg","haswebp":1,"hash":"0d817adf5bb448838705a85350d091597511026cb8b5e6f3d071fa36e3ef4642","height":2880}],"type":"manga","language":"korean","date":"2019-02-12 14:13:00-06","id":"1364233","japanese_title":null,"language_localname":"한국어","title":"\"Boku wa Kimi ga Suki\" | 「나는 네가 좋아」"} ''';
     */

    flutterJs.evaluate('''
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

      
function hitomi_get_header_content(id) {
  return JSON.stringify({
      'referer': `https://hitomi.la/reader/123456.html`,
      'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
      'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.3',
  });
}
    ''');

    // var xx = flutterJs
    //     .evaluate(
    //         "hitomi_get_image_list('12456',\"${tt.replaceAll('"', '\\"')}\")")
    //     .rawResult as Map<dynamic, dynamic>;

    // print("${tt.replaceAll('"', '\\"')}");
    // final jResult = flutterJs
    //     .evaluate(
    //         "hitomi_get_image_list('12456', \"${tt.replaceAll('"', '\\"')}\")")
    //     .stringResult;
    // final jResultObject = jsonDecode(jResult);

    // if (jResultObject is Map<dynamic, dynamic>) {
    //   print(jResultObject['result']);
    // }

    final jResult =
        flutterJs.evaluate("hitomi_get_header_content('12456')").stringResult;
    final jResultObject = jsonDecode(jResult);
    print(Map<String, String>.from(jResultObject));

    // expect(jResult, 'mm3');
  });
}
