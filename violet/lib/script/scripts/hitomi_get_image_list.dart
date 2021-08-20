// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/script/script_runner.dart';

class ScriptHitomiGetImageList {
  static const String code = """
gg = download(concat("https://ltn.hitomi.la/galleries/", \$id, ".js"))

if (startswith(trim(gg), "<html>"))
  print("no!!")
else [
  files = mapfromjson(substr(gg, add(indexof(gg, "="), 1)))["files"]

  number_of_frontends = 3
  \$id = tostring(\$id)
  subdomain = fromcharcode(add(97, mod(codeunitat(\$id, 
      sub(len(\$id), 1)), number_of_frontends)))

  btresult = listcreate()
  stresult = listcreate()
  result = listcreate()
  foreach (e : files) [
    hash = e["hash"]
    postfix = substr(hash, sub(len(hash), 3))
    subdomainx = subdomain

    if (or(not(containskey(e, "haswebp")), eq(e["haswebp"], 0)))
      subdomainx = "b"

    if (ishexint(substr(postfix, 0, 2))) [
      x = hextoint(substr(postfix, 0, 2))

      o = 0
      if (ls(x, 136)) o = 1
      if (ls(x, 68)) o = 2
      subdomainx = fromcharcode(add(97, o))
    ]

    p0 = at(postfix, 0)
    p1 = at(postfix, 1)
    p2 = at(postfix, 2)

    if (or(not(containskey(e, "haswebp")), eq(e["haswebp"], 0)))
      append(result, concat("https://", subdomainx, "b.hitomi.la/images/", p2, "/", p0, p1, "/", hash, ".", split(e["name"],".")[-1]))
    else if (eq(hash, ""))
      append(result, concat("https://", subdomainx, "a.hitomi.la/webp/", e["name"], ".webp"))
    else if (ls(len(hash), 3))
      append(result, concat("https://", subdomainx, "a.hitomi.la/webp/", hash, ".webp"))
    else
      append(result, concat("https://", subdomainx, "b.hitomi.la/webp/", p2, "/", p0, p1, "/", hash, ".webp"))
    append(btresult, concat("https://tn.hitomi.la/bigtn/", p2, "/", p0, p1, "/", hash, ".jpg"))
    append(stresult, concat("https://", subdomainx, "tn.hitomi.la/smalltn/", p2, "/", p0, p1, "/", hash, ".jpg"))
  ]

  \$result = mapcreate()
  mapinsert(\$result, "result", result)
  mapinsert(\$result, "stresult", stresult)
  mapinsert(\$result, "btresult", btresult)
]
  """;

  static Future<Map<String, dynamic>> run(int id) async {
    var sr = ScriptRunner(code);
    await sr.runScript({
      '\$id': RunVariable.fromInt(id),
      '\$result': RunVariable(isReady: false),
    });
    return sr.getValue('\$result').toMap();
  }

  /*
    print(await ScriptHitomiGetImageList.run(1987576));
  
  {
   "result":[
      "https"://bb.hitomi.la/webp/6/62/1d8546cb6e6c161d5184b26ae5675c831bbb1674d32745ad56f0b50b13fbd626.webp,
      "https"://bb.hitomi.la/webp/a/65/054cafb7c2e2cbe61d48d5adee623731ce35486567b06ca35c11df5ef45de65a.webp,
      "https"://cb.hitomi.la/webp/1/1c/fd4d865abb4d80a6bf69a0837de66d8c0e789cc6f1c716b61e57e5674e9e51c1.webp,
      "https"://cb.hitomi.la/webp/b/3a/1c6c41f9e73afc21cf882d65bd023f0bd762939c0efbd1513f5eb9dd39d863ab.webp,
      "https"://cb.hitomi.la/webp/8/32/7b21bf76d5d934150369f3b7b8656dc7a05eff6a3b8b3819e2eececc95756328.webp,
      "https"://ab.hitomi.la/webp/b/cc/ec35b445931c05f3d89ca80baf7f8ea3eb0d87f73d623132ef6ceb6ba46beccb.webp,
      "https"://ab.hitomi.la/webp/d/c8/9308ef1e7171818cd37ae69870f81450d63a9c68a8b587a52c9066d987738c8d.webp,
      "https"://cb.hitomi.la/webp/2/32/567f2496c559d5c68d63182e675941b349f10304e0a05fdd969be6190b4c6322.webp,
      "https"://ab.hitomi.la/webp/2/f4/6c1f1c16a7c8d3a02bb640c1965de8e0d7572df30852a303182e496a0259cf42.webp,
      "https"://cb.hitomi.la/webp/f/0a/efd124d17725131a406dfed50bc5f9c201d6b1dc3c4ccd34c39c0209401df0af.webp,
      "https"://ab.hitomi.la/webp/6/f1/36c90c4a8453b0be5f2ea422908a92669ea52fee00953bb99f2f088864cb7f16.webp,
      "https"://bb.hitomi.la/webp/3/7b/b40645d0a33d4be3d26c7d7a650106442f290d7a976028b2c27bb1b4b8e7f7b3.webp,
      "https"://bb.hitomi.la/webp/a/5d/f75b78e2f273761b29bbad34ac4c37e9aa05837620aede79722b520a0166f5da.webp,
      "https"://bb.hitomi.la/webp/b/52/1a59ebd958b672d75a97ba3dc61f237f5c6f6dcfc4ac520dbfa648020649252b.webp,
      "https"://bb.hitomi.la/webp/3/4f/3b034a02c8d7af21c67155722859df4a3b7897b1a3f157a1881b454d1af624f3.webp,
      "https"://cb.hitomi.la/webp/2/15/03a0c269d93b4be69ff356c91c9ff0add23fd074bf8be2891389fe10f0b9d152.webp,
      "https"://cb.hitomi.la/webp/1/25/c6c8f12f3ba39951789926a17498628e8e2dc0b6eb009665ecf33f435a113251.webp,
      "https"://bb.hitomi.la/webp/4/83/016476a07bbf503aef6eefd2b0021878f051683436754ce15b3dca5e0fd0e834.webp,
      "https"://ab.hitomi.la/webp/1/c6/83989aff722bf599ac0aa2bc46df3100d6ef9012a5cea58c13e7ca9c77442c61.webp,
      "https"://bb.hitomi.la/webp/a/64/f6f2997c8a61eb79994699ce98d4f6b255dc558d48b11fc8dc08ee4fe511764a.webp,
      "https"://bb.hitomi.la/webp/a/49/c308208184f65756237f627450bc0e7ebc206f9caf328a0ee218afa36932f49a.webp,
      "https"://cb.hitomi.la/webp/c/1f/416efa31bdeeaa61d8e317303b5bad7db43c4174c07d572e4fc7ffc907f1f1fc.webp,
      "https"://bb.hitomi.la/webp/a/52/70a726dd4def5148a657dc5dc1227f3365e543d80153080e947bc8218569f52a.webp,
      "https"://cb.hitomi.la/webp/f/35/7e706d5706898033a55335b333598ab4619e4e9151e080a85b4f18e0aee5535f.webp,
      "https"://cb.hitomi.la/webp/9/03/56d09d22fc91d5be8759055db428067cf532c7d17c67f90f2660885baa837039.webp,
      "https"://ab.hitomi.la/webp/2/d6/74b85f74e9ee37ff61725961f77bc8e2b4d76af8ff22f4b6c8ab6f03dbbdad62.webp,
      "https"://cb.hitomi.la/webp/6/01/d65549344ef507e8a3ea2a581cdacd09a9eb6b8cea0c1976b812f9a50e32f016.webp,
      "https"://ab.hitomi.la/webp/5/d0/a4ef991aa3f93a00d8deddf52d161e468a20e84df14b29b0a968b78c0ccf8d05.webp,
      "https"://bb.hitomi.la/webp/e/55/15c1d48124980c056f90605b170637dd466c9c307eedf4277a186f627bcf255e.webp,
      "https"://ab.hitomi.la/webp/b/a0/e1a90cb190c78529de3ae448af7b8f8959b6cf663b4fd924dbdedfc2b5426a0b.webp,
      "https"://ab.hitomi.la/webp/9/e0/86b17eb86a96bc178ede96df9d5211818b2918053726fca4a43da786524d8e09.webp,
      "https"://cb.hitomi.la/webp/3/01/f495ffec99f1dd5846c90585fe8fb871d43aeffa767d3f851c0fc13e580fa013.webp,
      "https"://ab.hitomi.la/webp/0/ab/fc82404714db125acd536043279beaaa11e5e11f8a518e963f104ff6b2ef2ab0.webp,
      "https"://ab.hitomi.la/webp/2/8e/100141c3f71fef22530a344bcd162379d6e851e8bc4f964162e8a0295412d8e2.webp,
      "https"://bb.hitomi.la/webp/9/46/6404ff8ac215e3deb8ef0556cdce7edd218cb1bbd707f6117b25297956cc3469.webp,
      "https"://ab.hitomi.la/webp/b/d8/8ca497f8e72c660a5f5a48f282f0632f72c35b75ed38df9b31148490065c0d8b.webp,
      "https"://bb.hitomi.la/webp/2/5f/67df028438bdaf1cab93738acf66eebeb6a4b0d3934d7c2711fc95db051d95f2.webp,
      "https"://ab.hitomi.la/webp/3/a0/5ab558ab38506e1e963bb0ef52ec04343e0880eccf5d33a2642434d2a038aa03.webp,
      "https"://bb.hitomi.la/webp/a/6e/ccf20b27c7b096d7877145081c34d1d1cecd0d5a8e9edecc1b3613511b5856ea.webp,
      "https"://ab.hitomi.la/webp/0/e8/e6921db4b1da2b4bf0c5c3db1319fc5799eb44843397db65f0bdebb2344dfe80.webp,
      "https"://ab.hitomi.la/webp/2/d9/b2e6aae7785f0a598a3631f15d4cac7e5f4358f791db8e7f1a64f69d5ed98d92.webp,
      "https"://ab.hitomi.la/webp/6/bd/5718550d261332ad597184924109b2b954a56a0afab24161938ecffef3d78bd6.webp,
      "https"://ab.hitomi.la/webp/7/fe/b4487a43c6bca94bf31b2f324ea824b6a2cda0ba870099794ddbadb8cf1e4fe7.webp,
      "https"://ab.hitomi.la/webp/2/d4/31fb7ee6ccabbe4c490180d4f777bd94b00637847f3caed59f20c028a4780d42.webp,
      "https"://bb.hitomi.la/webp/7/6e/89677899d7bed07ed2665cec4cae2d0f8aa4d1ff0d8ebe5d3315c7f12c9496e7.webp,
      "https"://ab.hitomi.la/webp/2/dd/78df7412edd6a084ea4fd9d563bea6e6634badcf10f0af84d5cf9a074be13dd2.webp
   ],
   "stresult":[
      "https"://btn.hitomi.la/smalltn/6/62/1d8546cb6e6c161d5184b26ae5675c831bbb1674d32745ad56f0b50b13fbd626.jpg,
      "https"://btn.hitomi.la/smalltn/a/65/054cafb7c2e2cbe61d48d5adee623731ce35486567b06ca35c11df5ef45de65a.jpg,
      "https"://ctn.hitomi.la/smalltn/1/1c/fd4d865abb4d80a6bf69a0837de66d8c0e789cc6f1c716b61e57e5674e9e51c1.jpg,
      "https"://ctn.hitomi.la/smalltn/b/3a/1c6c41f9e73afc21cf882d65bd023f0bd762939c0efbd1513f5eb9dd39d863ab.jpg,
      "https"://ctn.hitomi.la/smalltn/8/32/7b21bf76d5d934150369f3b7b8656dc7a05eff6a3b8b3819e2eececc95756328.jpg,
      "https"://atn.hitomi.la/smalltn/b/cc/ec35b445931c05f3d89ca80baf7f8ea3eb0d87f73d623132ef6ceb6ba46beccb.jpg,
      "https"://atn.hitomi.la/smalltn/d/c8/9308ef1e7171818cd37ae69870f81450d63a9c68a8b587a52c9066d987738c8d.jpg,
      "https"://ctn.hitomi.la/smalltn/2/32/567f2496c559d5c68d63182e675941b349f10304e0a05fdd969be6190b4c6322.jpg,
      "https"://atn.hitomi.la/smalltn/2/f4/6c1f1c16a7c8d3a02bb640c1965de8e0d7572df30852a303182e496a0259cf42.jpg,
      "https"://ctn.hitomi.la/smalltn/f/0a/efd124d17725131a406dfed50bc5f9c201d6b1dc3c4ccd34c39c0209401df0af.jpg,
      "https"://atn.hitomi.la/smalltn/6/f1/36c90c4a8453b0be5f2ea422908a92669ea52fee00953bb99f2f088864cb7f16.jpg,
      "https"://btn.hitomi.la/smalltn/3/7b/b40645d0a33d4be3d26c7d7a650106442f290d7a976028b2c27bb1b4b8e7f7b3.jpg,
      "https"://btn.hitomi.la/smalltn/a/5d/f75b78e2f273761b29bbad34ac4c37e9aa05837620aede79722b520a0166f5da.jpg,
      "https"://btn.hitomi.la/smalltn/b/52/1a59ebd958b672d75a97ba3dc61f237f5c6f6dcfc4ac520dbfa648020649252b.jpg,
      "https"://btn.hitomi.la/smalltn/3/4f/3b034a02c8d7af21c67155722859df4a3b7897b1a3f157a1881b454d1af624f3.jpg,
      "https"://ctn.hitomi.la/smalltn/2/15/03a0c269d93b4be69ff356c91c9ff0add23fd074bf8be2891389fe10f0b9d152.jpg,
      "https"://ctn.hitomi.la/smalltn/1/25/c6c8f12f3ba39951789926a17498628e8e2dc0b6eb009665ecf33f435a113251.jpg,
      "https"://btn.hitomi.la/smalltn/4/83/016476a07bbf503aef6eefd2b0021878f051683436754ce15b3dca5e0fd0e834.jpg,
      "https"://atn.hitomi.la/smalltn/1/c6/83989aff722bf599ac0aa2bc46df3100d6ef9012a5cea58c13e7ca9c77442c61.jpg,
      "https"://btn.hitomi.la/smalltn/a/64/f6f2997c8a61eb79994699ce98d4f6b255dc558d48b11fc8dc08ee4fe511764a.jpg,
      "https"://btn.hitomi.la/smalltn/a/49/c308208184f65756237f627450bc0e7ebc206f9caf328a0ee218afa36932f49a.jpg,
      "https"://ctn.hitomi.la/smalltn/c/1f/416efa31bdeeaa61d8e317303b5bad7db43c4174c07d572e4fc7ffc907f1f1fc.jpg,
      "https"://btn.hitomi.la/smalltn/a/52/70a726dd4def5148a657dc5dc1227f3365e543d80153080e947bc8218569f52a.jpg,
      "https"://ctn.hitomi.la/smalltn/f/35/7e706d5706898033a55335b333598ab4619e4e9151e080a85b4f18e0aee5535f.jpg,
      "https"://ctn.hitomi.la/smalltn/9/03/56d09d22fc91d5be8759055db428067cf532c7d17c67f90f2660885baa837039.jpg,
      "https"://atn.hitomi.la/smalltn/2/d6/74b85f74e9ee37ff61725961f77bc8e2b4d76af8ff22f4b6c8ab6f03dbbdad62.jpg,
      "https"://ctn.hitomi.la/smalltn/6/01/d65549344ef507e8a3ea2a581cdacd09a9eb6b8cea0c1976b812f9a50e32f016.jpg,
      "https"://atn.hitomi.la/smalltn/5/d0/a4ef991aa3f93a00d8deddf52d161e468a20e84df14b29b0a968b78c0ccf8d05.jpg,
      "https"://btn.hitomi.la/smalltn/e/55/15c1d48124980c056f90605b170637dd466c9c307eedf4277a186f627bcf255e.jpg,
      "https"://atn.hitomi.la/smalltn/b/a0/e1a90cb190c78529de3ae448af7b8f8959b6cf663b4fd924dbdedfc2b5426a0b.jpg,
      "https"://atn.hitomi.la/smalltn/9/e0/86b17eb86a96bc178ede96df9d5211818b2918053726fca4a43da786524d8e09.jpg,
      "https"://ctn.hitomi.la/smalltn/3/01/f495ffec99f1dd5846c90585fe8fb871d43aeffa767d3f851c0fc13e580fa013.jpg,
      "https"://atn.hitomi.la/smalltn/0/ab/fc82404714db125acd536043279beaaa11e5e11f8a518e963f104ff6b2ef2ab0.jpg,
      "https"://atn.hitomi.la/smalltn/2/8e/100141c3f71fef22530a344bcd162379d6e851e8bc4f964162e8a0295412d8e2.jpg,
      "https"://btn.hitomi.la/smalltn/9/46/6404ff8ac215e3deb8ef0556cdce7edd218cb1bbd707f6117b25297956cc3469.jpg,
      "https"://atn.hitomi.la/smalltn/b/d8/8ca497f8e72c660a5f5a48f282f0632f72c35b75ed38df9b31148490065c0d8b.jpg,
      "https"://btn.hitomi.la/smalltn/2/5f/67df028438bdaf1cab93738acf66eebeb6a4b0d3934d7c2711fc95db051d95f2.jpg,
      "https"://atn.hitomi.la/smalltn/3/a0/5ab558ab38506e1e963bb0ef52ec04343e0880eccf5d33a2642434d2a038aa03.jpg,
      "https"://btn.hitomi.la/smalltn/a/6e/ccf20b27c7b096d7877145081c34d1d1cecd0d5a8e9edecc1b3613511b5856ea.jpg,
      "https"://atn.hitomi.la/smalltn/0/e8/e6921db4b1da2b4bf0c5c3db1319fc5799eb44843397db65f0bdebb2344dfe80.jpg,
      "https"://atn.hitomi.la/smalltn/2/d9/b2e6aae7785f0a598a3631f15d4cac7e5f4358f791db8e7f1a64f69d5ed98d92.jpg,
      "https"://atn.hitomi.la/smalltn/6/bd/5718550d261332ad597184924109b2b954a56a0afab24161938ecffef3d78bd6.jpg,
      "https"://atn.hitomi.la/smalltn/7/fe/b4487a43c6bca94bf31b2f324ea824b6a2cda0ba870099794ddbadb8cf1e4fe7.jpg,
      "https"://atn.hitomi.la/smalltn/2/d4/31fb7ee6ccabbe4c490180d4f777bd94b00637847f3caed59f20c028a4780d42.jpg,
      "https"://btn.hitomi.la/smalltn/7/6e/89677899d7bed07ed2665cec4cae2d0f8aa4d1ff0d8ebe5d3315c7f12c9496e7.jpg,
      "https"://atn.hitomi.la/smalltn/2/dd/78df7412edd6a084ea4fd9d563bea6e6634badcf10f0af84d5cf9a074be13dd2.jpg
   ],
   "btresult":[
      "https"://tn.hitomi.la/bigtn/6/62/1d8546cb6e6c161d5184b26ae5675c831bbb1674d32745ad56f0b50b13fbd626.jpg,
      "https"://tn.hitomi.la/bigtn/a/65/054cafb7c2e2cbe61d48d5adee623731ce35486567b06ca35c11df5ef45de65a.jpg,
      "https"://tn.hitomi.la/bigtn/1/1c/fd4d865abb4d80a6bf69a0837de66d8c0e789cc6f1c716b61e57e5674e9e51c1.jpg,
      "https"://tn.hitomi.la/bigtn/b/3a/1c6c41f9e73afc21cf882d65bd023f0bd762939c0efbd1513f5eb9dd39d863ab.jpg,
      "https"://tn.hitomi.la/bigtn/8/32/7b21bf76d5d934150369f3b7b8656dc7a05eff6a3b8b3819e2eececc95756328.jpg,
      "https"://tn.hitomi.la/bigtn/b/cc/ec35b445931c05f3d89ca80baf7f8ea3eb0d87f73d623132ef6ceb6ba46beccb.jpg,
      "https"://tn.hitomi.la/bigtn/d/c8/9308ef1e7171818cd37ae69870f81450d63a9c68a8b587a52c9066d987738c8d.jpg,
      "https"://tn.hitomi.la/bigtn/2/32/567f2496c559d5c68d63182e675941b349f10304e0a05fdd969be6190b4c6322.jpg,
      "https"://tn.hitomi.la/bigtn/2/f4/6c1f1c16a7c8d3a02bb640c1965de8e0d7572df30852a303182e496a0259cf42.jpg,
      "https"://tn.hitomi.la/bigtn/f/0a/efd124d17725131a406dfed50bc5f9c201d6b1dc3c4ccd34c39c0209401df0af.jpg,
      "https"://tn.hitomi.la/bigtn/6/f1/36c90c4a8453b0be5f2ea422908a92669ea52fee00953bb99f2f088864cb7f16.jpg,
      "https"://tn.hitomi.la/bigtn/3/7b/b40645d0a33d4be3d26c7d7a650106442f290d7a976028b2c27bb1b4b8e7f7b3.jpg,
      "https"://tn.hitomi.la/bigtn/a/5d/f75b78e2f273761b29bbad34ac4c37e9aa05837620aede79722b520a0166f5da.jpg,
      "https"://tn.hitomi.la/bigtn/b/52/1a59ebd958b672d75a97ba3dc61f237f5c6f6dcfc4ac520dbfa648020649252b.jpg,
      "https"://tn.hitomi.la/bigtn/3/4f/3b034a02c8d7af21c67155722859df4a3b7897b1a3f157a1881b454d1af624f3.jpg,
      "https"://tn.hitomi.la/bigtn/2/15/03a0c269d93b4be69ff356c91c9ff0add23fd074bf8be2891389fe10f0b9d152.jpg,
      "https"://tn.hitomi.la/bigtn/1/25/c6c8f12f3ba39951789926a17498628e8e2dc0b6eb009665ecf33f435a113251.jpg,
      "https"://tn.hitomi.la/bigtn/4/83/016476a07bbf503aef6eefd2b0021878f051683436754ce15b3dca5e0fd0e834.jpg,
      "https"://tn.hitomi.la/bigtn/1/c6/83989aff722bf599ac0aa2bc46df3100d6ef9012a5cea58c13e7ca9c77442c61.jpg,
      "https"://tn.hitomi.la/bigtn/a/64/f6f2997c8a61eb79994699ce98d4f6b255dc558d48b11fc8dc08ee4fe511764a.jpg,
      "https"://tn.hitomi.la/bigtn/a/49/c308208184f65756237f627450bc0e7ebc206f9caf328a0ee218afa36932f49a.jpg,
      "https"://tn.hitomi.la/bigtn/c/1f/416efa31bdeeaa61d8e317303b5bad7db43c4174c07d572e4fc7ffc907f1f1fc.jpg,
      "https"://tn.hitomi.la/bigtn/a/52/70a726dd4def5148a657dc5dc1227f3365e543d80153080e947bc8218569f52a.jpg,
      "https"://tn.hitomi.la/bigtn/f/35/7e706d5706898033a55335b333598ab4619e4e9151e080a85b4f18e0aee5535f.jpg,
      "https"://tn.hitomi.la/bigtn/9/03/56d09d22fc91d5be8759055db428067cf532c7d17c67f90f2660885baa837039.jpg,
      "https"://tn.hitomi.la/bigtn/2/d6/74b85f74e9ee37ff61725961f77bc8e2b4d76af8ff22f4b6c8ab6f03dbbdad62.jpg,
      "https"://tn.hitomi.la/bigtn/6/01/d65549344ef507e8a3ea2a581cdacd09a9eb6b8cea0c1976b812f9a50e32f016.jpg,
      "https"://tn.hitomi.la/bigtn/5/d0/a4ef991aa3f93a00d8deddf52d161e468a20e84df14b29b0a968b78c0ccf8d05.jpg,
      "https"://tn.hitomi.la/bigtn/e/55/15c1d48124980c056f90605b170637dd466c9c307eedf4277a186f627bcf255e.jpg,
      "https"://tn.hitomi.la/bigtn/b/a0/e1a90cb190c78529de3ae448af7b8f8959b6cf663b4fd924dbdedfc2b5426a0b.jpg,
      "https"://tn.hitomi.la/bigtn/9/e0/86b17eb86a96bc178ede96df9d5211818b2918053726fca4a43da786524d8e09.jpg,
      "https"://tn.hitomi.la/bigtn/3/01/f495ffec99f1dd5846c90585fe8fb871d43aeffa767d3f851c0fc13e580fa013.jpg,
      "https"://tn.hitomi.la/bigtn/0/ab/fc82404714db125acd536043279beaaa11e5e11f8a518e963f104ff6b2ef2ab0.jpg,
      "https"://tn.hitomi.la/bigtn/2/8e/100141c3f71fef22530a344bcd162379d6e851e8bc4f964162e8a0295412d8e2.jpg,
      "https"://tn.hitomi.la/bigtn/9/46/6404ff8ac215e3deb8ef0556cdce7edd218cb1bbd707f6117b25297956cc3469.jpg,
      "https"://tn.hitomi.la/bigtn/b/d8/8ca497f8e72c660a5f5a48f282f0632f72c35b75ed38df9b31148490065c0d8b.jpg,
      "https"://tn.hitomi.la/bigtn/2/5f/67df028438bdaf1cab93738acf66eebeb6a4b0d3934d7c2711fc95db051d95f2.jpg,
      "https"://tn.hitomi.la/bigtn/3/a0/5ab558ab38506e1e963bb0ef52ec04343e0880eccf5d33a2642434d2a038aa03.jpg,
      "https"://tn.hitomi.la/bigtn/a/6e/ccf20b27c7b096d7877145081c34d1d1cecd0d5a8e9edecc1b3613511b5856ea.jpg,
      "https"://tn.hitomi.la/bigtn/0/e8/e6921db4b1da2b4bf0c5c3db1319fc5799eb44843397db65f0bdebb2344dfe80.jpg,
      "https"://tn.hitomi.la/bigtn/2/d9/b2e6aae7785f0a598a3631f15d4cac7e5f4358f791db8e7f1a64f69d5ed98d92.jpg,
      "https"://tn.hitomi.la/bigtn/6/bd/5718550d261332ad597184924109b2b954a56a0afab24161938ecffef3d78bd6.jpg,
      "https"://tn.hitomi.la/bigtn/7/fe/b4487a43c6bca94bf31b2f324ea824b6a2cda0ba870099794ddbadb8cf1e4fe7.jpg,
      "https"://tn.hitomi.la/bigtn/2/d4/31fb7ee6ccabbe4c490180d4f777bd94b00637847f3caed59f20c028a4780d42.jpg,
      "https"://tn.hitomi.la/bigtn/7/6e/89677899d7bed07ed2665cec4cae2d0f8aa4d1ff0d8ebe5d3315c7f12c9496e7.jpg,
      "https"://tn.hitomi.la/bigtn/2/dd/78df7412edd6a084ea4fd9d563bea6e6634badcf10f0af84d5cf9a074be13dd2.jpg
    ]
  }
   */
}
