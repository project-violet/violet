// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/component/downloadable.dart';
import 'package:violet/downloader/isolate_downloader.dart';

String intToString(int i, {int pad = 0}) {
  var str = i.toString();
  var paddingToAdd = pad - str.length;
  return (paddingToAdd > 0)
      ? "${List.filled(paddingToAdd, '0').join('')}$i"
      : str;
}

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
  });

  test('Test Downloader Isolate', () async {
    // 2116987
    // const urls = [
    //   "https://ba.hitomi.la/webp/1641389178/1666/e6e25716f0e9147570fe5c2dc1fe7b8371e7052155c6699d31ac243813c2d826.webp",
    //   "https://aa.hitomi.la/webp/1641389178/367/9c56dd7045b836a17d657640ca9084a285f4becef6bff4b3b4017575e81eb6f1.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1471/6a60c1256b727dd86ffcb2dca7b459b54b634a0cfcb929470fe7c73a4bb14bf5.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1520/109cac3969fe345158839849bd34c5881585167b48f8011d5b9ad46bf951ff05.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1083/493ae3e51b5de97183b68423323b5701e5a9b6eab5625f8fcf31b2716db0a3b4.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3619/b2f5076f5f1f69dbf4b5908030d782d540482bdb659f8930006d02d51145223e.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1794/4e843fec8da7ba1bb8a185cc18a7a7f38159332959d42c1497818d84c99af027.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1028/6fc5da8d1601822a0a24e2573067f320aee0762b2d3ad07d9fbbed7561e7c044.webp",
    //   "https://ba.hitomi.la/webp/1641389178/2000/662dcbcbb01f141e10bcd9e39eea4d91fb1cff3297fde83570fc33201acc0d07.webp",
    //   "https://ba.hitomi.la/webp/1641389178/696/9fe3bef3207fe2acf5f6a210d1a82ccb8ddec351c9ebe28fa110f702b4138b82.webp",
    //   "https://aa.hitomi.la/webp/1641389178/2702/8a833e9edd814eac36b3ed4a8ba03e9490706285f3e50daf9eecb28f1c8e98ea.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1419/f98bee292b9ed8ff8cd38bfd20d61acae55315f0335b29280fbc9673c7f198b5.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3404/dab02c0d0e7477026f650ebdd2ee02528d2a590b4ac82a7656ee6c4fb8cab4cd.webp",
    //   "https://aa.hitomi.la/webp/1641389178/129/f4e44e5d437839c1955d197f3e1a5d3abc45238552b2e6ad929db3c625e64810.webp",
    //   "https://ba.hitomi.la/webp/1641389178/603/923b319e8a2a339830348f0b2a34a90c5706e20d251725bf57affd2db5f855b2.webp",
    //   "https://aa.hitomi.la/webp/1641389178/113/8e14d977835cbfcfe56ff39fccc8c4cab78c5e50ff5f20b959175d9488e16710.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1805/39dd653febfe6f913b9ece70ea68275d0e859fc2cc135b97cab841cea60a40d7.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1617/efcda47bc40f71982a5278964b99755dd05f635141d91abf8f5684e535040516.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1652/f87302ac0c698a796df5cff98584f3f1cbf6871223e275682ba5d70be32cb746.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1294/4c20da4de3b465709622fc1043eeba63f38be82a8285ae088aa247ed147fe0e5.webp",
    //   "https://aa.hitomi.la/webp/1641389178/69/1f9ff7cba2a0a47ffc4b4aee2569ff7cc886f561caf12e89c32e41c060994450.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1136/695ad3a6c3f8ab115798c8657488bb3cfb44c900ca7cef85e0d140f978a0a704.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1860/0c6f48a76b8302baeab4fc9a2062f956c7eefc75c575f62d58dfabb2f9def447.webp",
    //   "https://aa.hitomi.la/webp/1641389178/672/514b5708bc9b595551374aec087bbec38ba1e169346002a3bd132a96bb2c0a02.webp",
    //   "https://aa.hitomi.la/webp/1641389178/2455/b3193b439650b28bcb18515958d7e83301166c8bfeaaecfbb83ee259bf9f6979.webp",
    //   "https://aa.hitomi.la/webp/1641389178/2929/e320be96661ed7453c2278f8bbe761d13cd7bc3ec8354922791fcf06416f671b.webp",
    //   "https://ba.hitomi.la/webp/1641389178/2713/bd01354c8c84d375ebeff0a2e2e461d84a1e10b53ecabefaccd24334d677399a.webp",
    //   "https://aa.hitomi.la/webp/1641389178/3396/d15e4bb580cce26267dfa5a1d1292c1ffb391b0257963c9f308fbf24e336d44d.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1296/5f28e345b1f18c4a12beff02f58a2715d1f52c979152918334047db75446a105.webp",
    //   "https://aa.hitomi.la/webp/1641389178/808/b6fbc43f855a8921bb2ae18859bc1d426c82d232b7fd8ff538b4e7f363891283.webp",
    //   "https://aa.hitomi.la/webp/1641389178/2219/a307a3c853b73d2ed05ab3521e84963f02534521cffb54b796c6d258fb80eab8.webp",
    //   "https://aa.hitomi.la/webp/1641389178/2878/79d5d62a032c021921c8a82622446ee88a1b278aacb40f101019e359353db3eb.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3850/9aac4ef2852469f7c4962042326eefacc5d07a4f7485e3f539d8a3b50fe500af.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1938/358ac77ccb69af1ef485aa9b92c1799c54c64383fc2f0fc0a83bbd6ab41e1927.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1562/3099e93055630c1c43a158d61418575b1ba83c98e457b23b1dde8c9c78e791a6.webp",
    //   "https://ba.hitomi.la/webp/1641389178/2353/fe7f518034b0c48a76db2cf900d662667ca0d177ad014572b492c62b84380319.webp",
    //   "https://aa.hitomi.la/webp/1641389178/33/1dc7b5812d5253b14ec320d77c45542a0139130923bc81d4115494f5c6dc5210.webp",
    //   "https://aa.hitomi.la/webp/1641389178/2480/8204d5ad63f6c8c5da482abe24b14358cb3f626c51962d9eeeeba3e987b7eb09.webp",
    //   "https://ba.hitomi.la/webp/1641389178/4081/9cecf1f8adc453d4223eec44deeb84427d413e9e75ac4d749ce57c0cd46c8f1f.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1137/7043111d5777c5a1cca91af5020006f532ec7ddb3595ad00918d8234b344b714.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1575/0a675ef20be2f5a95f48d3b76408e90e84e2aff96aed3c1c1c5092edc745b276.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3125/d7b742384016a4fd490c593b7c7977669a602cf24ace5d238179a32f44b6b35c.webp",
    //   "https://aa.hitomi.la/webp/1641389178/3796/879f4d5c5eb03fb2d9b092888a18bcbc977ef284c210711627b490557f1aad4e.webp",
    //   "https://aa.hitomi.la/webp/1641389178/2981/19e9b8b66045841e75ba77d941fdbf121831b27c3b7429e5f63e5b42c8d9ea5b.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3437/43e5755461a7377a76d26aeec0ca3afcc2dbfed118ec45e087963ea0e935b6dd.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3970/837f3b0dd52842630658b8e6d84c63e7eef2fcfa3504478d7206a53237e3982f.webp",
    //   "https://ba.hitomi.la/webp/1641389178/2000/189f1d295f96efb49a8d2899168e145a24cff414899c5f57fb8145b6d22ecd07.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1792/1297580cdad829404d9db8f8e22eb01955e47f991bdd6a1afa3dc7fdc420c007.webp",
    //   "https://ba.hitomi.la/webp/1641389178/237/e421448f2ea70fcddc4d21f3eab1d358c3200aee35caf96ade8746b579475ed0.webp",
    //   "https://ba.hitomi.la/webp/1641389178/2049/46557fc258a33d27c65ae5b258a37532625394b6dcb59833b5f0845f51837018.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3874/a0aeb06a3571cc9833db1e1ca73da91a3e54d423dc108cc2dbf835eb93d6322f.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3361/fbecd058763a22c8390a48cfeb1fcf358ed72b88039e0069c69be6117f66c21d.webp",
    //   "https://ba.hitomi.la/webp/1641389178/565/3552e3ae5c76e1e9af9120dc6370d307f15e8c1fc6ba8b598d9db1911c8c6352.webp",
    //   "https://ba.hitomi.la/webp/1641389178/890/835b70f5f1e62b413b16e86511fa442c8fda3e51380478ecfde2346dd51427a3.webp",
    //   "https://ba.hitomi.la/webp/1641389178/184/24d85e679954d898d7418c0359f8f210e1f8d77861e5282a88275d0da6826b80.webp",
    //   "https://ba.hitomi.la/webp/1641389178/2739/44cc8e72f15b940b247b314234eb8f6c3805eb42d21470d4bfec9149fd450b3a.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1800/11a5624042af249d6785457dfc144b4ae24d4d964ca0dd8a520de465b5682087.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1380/4d1aa27e3f568a217305da75e89b092da0a5f163e711a58b0bdac7c928126645.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1336/ea7c89fcf32c604488289250ce81cec17a07cf8edcdc9ed7c57324c72d16c385.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3245/6167f6989e5339b951be46b3f0319554df3767278bc8408013f5b69243e01adc.webp",
    //   "https://aa.hitomi.la/webp/1641389178/3026/199a90d28e60e4d97b9eb2ebfb55bed086496ee3dcc46debe47e497570dc1d2b.webp",
    //   "https://ba.hitomi.la/webp/1641389178/2301/af4196e0bc2d8874e729dc564852d1195f6b8a9338a5f03ac0baf7aac9ec4fd8.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1361/2ac46824261e4d90190205dda06ab9936cb35c51820b325101f02d01f6af2515.webp",
    //   "https://aa.hitomi.la/webp/1641389178/2382/884bc8727cd5ac53bf7c6f84c39884a06290e437efcd89fab6aa84ef368434e9.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1195/93f1ae1af4e8c50fa3e3bb340d17490a08d7dcaa26f589825f119dd3f25ebab4.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1691/3c8e87bbe222bc72c8a4470315fce5f9eb83945078dec0cc392706a4be5399b6.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1162/c775eccf5efd7f842536d9e9882a9e359e2560084908512a97696b9ac45b58a4.webp",
    //   "https://ba.hitomi.la/webp/1641389178/278/1afdedcdc66d41edc8f409263c6272f076daefc65f88e8fdc355b50da5969161.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1413/79d373e8485394a8e24ac562dd110f94c6d712f1abef60a1dfd8c48f8267e855.webp",
    //   "https://aa.hitomi.la/webp/1641389178/3052/11ab82c705b866e31a0e5b624a25a7698721aa52f19193a399aae599bb8ebecb.webp"
    // ];

    // 2073818
    // const urls = [
    //   "https://ba.hitomi.la/webp/1641389178/1652/8315dc8c1b9a90d89ac5604f9c472f7212ab9717b6329f2b3bd762790530f746.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1228/b3732b0f6a797f90e72e0b5722d670310b79b00beb34305795dce9916f8d7cc4.webp",
    //   "https://aa.hitomi.la/webp/1641389178/397/682f404807650bdc9add07c44040b3105706b185ca037cb1fbea7445a27ab8d1.webp",
    //   "https://ba.hitomi.la/webp/1641389178/2726/36e7400964627f9d5c2e4205bbfc98cc274d98bf3d30a884aa8bb9565c8e9a6a.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1173/51d887d157533e06cfcfebd7de8a2be867a2b1c8941f88f7ffabb4546a318954.webp",
    //   "https://aa.hitomi.la/webp/1641389178/736/b5b0ca26910f1974082298640f4c6902228910340ad15f726178f7cba6c03e02.webp",
    //   "https://ba.hitomi.la/webp/1641389178/106/e97a47dd698aa36a39ba5a0cbf959daeac6d88217c0dbaef3c33e2354df0d6a0.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1014/d8c94c4e950306ad0c6932c09861096626b2ec7817c5796e2d8cf0645473ef63.webp",
    //   "https://aa.hitomi.la/webp/1641389178/2809/b870ff8bce90e78b2441232522a2108ff816e66975bf5deb13e19e05ed590f9a.webp",
    //   "https://ba.hitomi.la/webp/1641389178/427/59231ba41fc747294460aa56a4238f60f3edca7e157f2ccc735e16c8c68afab1.webp",
    //   "https://aa.hitomi.la/webp/1641389178/3105/b9ce38aac47a63a7b071db1e2263876775d878d2b93dcdef978eb148c228121c.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3918/fc637fcdffc159ed4a5a07fc571975d91268083baa000c2f0e58911e18f224ef.webp",
    //   "https://aa.hitomi.la/webp/1641389178/3390/952489d51f3b73a8e9f242c7e53250f169205d0f573389bbcc8a7c35f536a3ed.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1775/e7be7105ae5160d166f3c165c91b228bec5e606951832d282fee9e2cd6a4aef6.webp",
    //   "https://ba.hitomi.la/webp/1641389178/2058/cb99f13161101d57a279b864bb7a945f08b1c722f31928ebc2ff48baee2350a8.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3447/6d74500b2bd2d1d7010129c919d7eeb76f2d7ebbc88afd87da59badaf653777d.webp",
    //   "https://aa.hitomi.la/webp/1641389178/688/ef526e63e7b99c2216eed920f2b8191ab955a0e1d33cffd01c5bb7decf6abb02.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3695/670182bb7eb0ab86f52f3fdfd5794284f2d1266c033d5d4ade1bc4ed145976fe.webp",
    //   "https://ba.hitomi.la/webp/1641389178/1727/5b568f3c6a32d63ad083078e94c741cb53cb9dc55fe7b337df20b7ea76881bf6.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3098/2d9ca34325f33ca9d8dffeb11401176a9819119fef7342438449e6e680cf01ac.webp",
    //   "https://aa.hitomi.la/webp/1641389178/2568/f04bf792ff02379ec96ee00c6da0edd11a650330211a4e0a73632e41ea3e808a.webp",
    //   "https://ba.hitomi.la/webp/1641389178/889/5b40f6be6dd08131e0de46b300c5504c610c064c8b5523bc3ccc371e2bfe1793.webp",
    //   "https://ba.hitomi.la/webp/1641389178/2018/3b135efe9954b0bc5e38d81c1cea6fcf95df8317681eb8f8ac7336862a830e27.webp",
    //   "https://ba.hitomi.la/webp/1641389178/3525/18e25accda28351115067235bc6460e3bdd2828df95d9c53a7977a45e4ba9c5d.webp",
    //   "https://ba.hitomi.la/webp/1641389178/324/b73daee63cc53a7f13cf2f9a1866fc86a902f263a322b41279adf9bf34443441.webp",
    //   "https://aa.hitomi.la/webp/1641389178/3286/30421846e32b9d546328e569ee967b2b26e3ea1f4dbefa65331d671513568d6c.webp",
    //   "https://aa.hitomi.la/webp/1641389178/795/fbf0b92111414137eec213e59b2db29a05e8b5fd646cb11a0b189c0cb441c1b3.webp",
    //   "https://ba.hitomi.la/webp/1641389178/832/b5dda21908a9f56174150615319a3c51aad25995ecdaa3ce7f571afeb5695403.webp",
    //   "https://aa.hitomi.la/webp/1641389178/3881/24be8ea197aa4c611b2cf80330de8d7d725d34181216ce03a77bad1af6ee429f.webp",
    //   "https://ba.hitomi.la/webp/1641389178/444/02ee1e1bdf43368e03971d0f609e32f163e2c3b0211d245934a4fcb3a0828bc1.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1528/8b008983172c8232c87963c3a0f627e20d5764b73dde8998d34af616d34d4f85.webp",
    //   "https://aa.hitomi.la/webp/1641389178/3689/4bee8bf49269363c5cec22cc7448f406db72ba56c138d554defe8c195ca1369e.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1328/ade340febf8a8a5d6b2af62e4eb176f8778c4adbb72315becdd224341b879305.webp",
    //   "https://ba.hitomi.la/webp/1641389178/2507/843020159cfb5550a2d17db2c249ba3fdd89d14897b125952ad6c5390a32ecb9.webp",
    //   "https://aa.hitomi.la/webp/1641389178/1809/a2b2b56a43124cb96d699140da697be6ce69697259757f505e50cec497cf4117.webp"
    // ];

    // 2073818 thumbnails
    const urls = [
      'https://tn.hitomi.la/avifsmalltn/6/74/8315dc8c1b9a90d89ac5604f9c472f7212ab9717b6329f2b3bd762790530f746.avif',
      'https://tn.hitomi.la/avifsmalltn/4/cc/b3732b0f6a797f90e72e0b5722d670310b79b00beb34305795dce9916f8d7cc4.avif',
      'https://tn.hitomi.la/avifsmalltn/1/8d/682f404807650bdc9add07c44040b3105706b185ca037cb1fbea7445a27ab8d1.avif',
      'https://tn.hitomi.la/avifsmalltn/a/a6/36e7400964627f9d5c2e4205bbfc98cc274d98bf3d30a884aa8bb9565c8e9a6a.avif',
      'https://tn.hitomi.la/avifsmalltn/4/95/51d887d157533e06cfcfebd7de8a2be867a2b1c8941f88f7ffabb4546a318954.avif',
      'https://tn.hitomi.la/avifsmalltn/2/e0/b5b0ca26910f1974082298640f4c6902228910340ad15f726178f7cba6c03e02.avif',
      'https://tn.hitomi.la/avifsmalltn/0/6a/e97a47dd698aa36a39ba5a0cbf959daeac6d88217c0dbaef3c33e2354df0d6a0.avif',
      'https://tn.hitomi.la/avifsmalltn/3/f6/d8c94c4e950306ad0c6932c09861096626b2ec7817c5796e2d8cf0645473ef63.avif',
      'https://tn.hitomi.la/avifsmalltn/a/f9/b870ff8bce90e78b2441232522a2108ff816e66975bf5deb13e19e05ed590f9a.avif',
      'https://tn.hitomi.la/avifsmalltn/1/ab/59231ba41fc747294460aa56a4238f60f3edca7e157f2ccc735e16c8c68afab1.avif',
      'https://tn.hitomi.la/avifsmalltn/c/21/b9ce38aac47a63a7b071db1e2263876775d878d2b93dcdef978eb148c228121c.avif',
      'https://tn.hitomi.la/avifsmalltn/f/4e/fc637fcdffc159ed4a5a07fc571975d91268083baa000c2f0e58911e18f224ef.avif',
      'https://tn.hitomi.la/avifsmalltn/d/3e/952489d51f3b73a8e9f242c7e53250f169205d0f573389bbcc8a7c35f536a3ed.avif',
      'https://tn.hitomi.la/avifsmalltn/6/ef/e7be7105ae5160d166f3c165c91b228bec5e606951832d282fee9e2cd6a4aef6.avif',
      'https://tn.hitomi.la/avifsmalltn/8/0a/cb99f13161101d57a279b864bb7a945f08b1c722f31928ebc2ff48baee2350a8.avif',
      'https://tn.hitomi.la/avifsmalltn/d/77/6d74500b2bd2d1d7010129c919d7eeb76f2d7ebbc88afd87da59badaf653777d.avif',
      'https://tn.hitomi.la/avifsmalltn/2/b0/ef526e63e7b99c2216eed920f2b8191ab955a0e1d33cffd01c5bb7decf6abb02.avif',
      'https://tn.hitomi.la/avifsmalltn/e/6f/670182bb7eb0ab86f52f3fdfd5794284f2d1266c033d5d4ade1bc4ed145976fe.avif',
      'https://tn.hitomi.la/avifsmalltn/6/bf/5b568f3c6a32d63ad083078e94c741cb53cb9dc55fe7b337df20b7ea76881bf6.avif',
      'https://tn.hitomi.la/avifsmalltn/c/1a/2d9ca34325f33ca9d8dffeb11401176a9819119fef7342438449e6e680cf01ac.avif',
      'https://tn.hitomi.la/avifsmalltn/a/08/f04bf792ff02379ec96ee00c6da0edd11a650330211a4e0a73632e41ea3e808a.avif',
      'https://tn.hitomi.la/avifsmalltn/3/79/5b40f6be6dd08131e0de46b300c5504c610c064c8b5523bc3ccc371e2bfe1793.avif',
      'https://tn.hitomi.la/avifsmalltn/7/e2/3b135efe9954b0bc5e38d81c1cea6fcf95df8317681eb8f8ac7336862a830e27.avif',
      'https://tn.hitomi.la/avifsmalltn/d/c5/18e25accda28351115067235bc6460e3bdd2828df95d9c53a7977a45e4ba9c5d.avif',
      'https://tn.hitomi.la/avifsmalltn/1/44/b73daee63cc53a7f13cf2f9a1866fc86a902f263a322b41279adf9bf34443441.avif',
      'https://tn.hitomi.la/avifsmalltn/c/d6/30421846e32b9d546328e569ee967b2b26e3ea1f4dbefa65331d671513568d6c.avif',
      'https://tn.hitomi.la/avifsmalltn/3/1b/fbf0b92111414137eec213e59b2db29a05e8b5fd646cb11a0b189c0cb441c1b3.avif',
      'https://tn.hitomi.la/avifsmalltn/3/40/b5dda21908a9f56174150615319a3c51aad25995ecdaa3ce7f571afeb5695403.avif',
      'https://tn.hitomi.la/avifsmalltn/f/29/24be8ea197aa4c611b2cf80330de8d7d725d34181216ce03a77bad1af6ee429f.avif',
      'https://tn.hitomi.la/avifsmalltn/1/bc/02ee1e1bdf43368e03971d0f609e32f163e2c3b0211d245934a4fcb3a0828bc1.avif',
      'https://tn.hitomi.la/avifsmalltn/5/f8/8b008983172c8232c87963c3a0f627e20d5764b73dde8998d34af616d34d4f85.avif',
      'https://tn.hitomi.la/avifsmalltn/e/69/4bee8bf49269363c5cec22cc7448f406db72ba56c138d554defe8c195ca1369e.avif',
      'https://tn.hitomi.la/avifsmalltn/5/30/ade340febf8a8a5d6b2af62e4eb176f8778c4adbb72315becdd224341b879305.avif',
      'https://tn.hitomi.la/avifsmalltn/9/cb/843020159cfb5550a2d17db2c249ba3fdd89d14897b125952ad6c5390a32ecb9.avif',
      'https://tn.hitomi.la/avifsmalltn/7/11/a2b2b56a43124cb96d699140da697be6ce69697259757f505e50cec497cf4117.avif'
    ];

    final downloader = IsolateDownloader();
    await downloader.init();
    await Future.delayed(const Duration(seconds: 1));

    int completeCount = 0;

    var tasks = <DownloadTask>[];
    for (int i = 0; i < urls.length; i++) {
      final task = DownloadTask(
        url: urls[i],
        downloadPath:
            'test/download/${intToString(i, pad: 3)}.${path.extension(urls[i].split('/').last).replaceAll('.', '')}',
        headers: {
          'referer': 'https://hitomi.la/reader/2116987.html',
          'accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
          'user-agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.3',
        },
      );
      tasks.add(task);
      task.completeCallback = () => completeCount += 1;
    }

    downloader.appendTasks(tasks);

    while (completeCount != tasks.length) {
      await Future.delayed(const Duration(seconds: 1));
    }
  });
}
