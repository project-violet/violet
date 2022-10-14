// This source code is a part of Project Violet.
// Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:typed_data';

import 'package:violet/cert/cert_util.dart';
import 'package:violet/cert/root.dart';

class CertData {
  Map<String, dynamic> data;
  CertData({required this.data});

  DateTime authStarts() => DateTime.parse(data['AuthStarts']).toLocal();
  DateTime authEnds() => DateTime.parse(data['AuthEnds']).toLocal();
  String authVersion() => data['AuthVersion'];
  String owner() => data['Owner']; // UserAppId
  String others() => data['Others'];

  String signedData() => data['SignedData'];

  String getRawData() => data.containsKey('Others')
      ? "${data['AuthStarts']}|${data['AuthEnds']}|${data['AuthVersion']}|${data['Owner']}|${data['Others']}"
      : "${data['AuthStarts']}|${data['AuthEnds']}|${data['AuthVersion']}|${data['Owner']}";

  bool verify(RootCert rootCA) {
    var rawData = getRawData();
    var rsaPub = rootCA.rsaPublic();

    return CertUtil.verify(rsaPub, Uint8List.fromList(rawData.codeUnits),
        base64.decode(signedData()));
  }

  String toBase64() {
    return utf8.fuse(base64).encode(jsonEncode(data));
  }

  static CertData fromBase64(String str) {
    return CertData(data: jsonDecode(utf8.fuse(base64).decode(str)));
  }

  static CertData testCert() => fromBase64('''
  eyJBdXRoU3RhcnRzIjoiMjAyMS0wOC0wNSAyMzowNjowNi42NjczMDVaIiwiQXV0aEVuZHMiOiIy
  MDMxLTA4LTA3IDIzOjA2OjA2LjY2ODgxM1oiLCJBdXRoVmVyc2lvbiI6IjEuMCIsIk93bmVyIjoi
  dGVzdCB1c2VyIiwiU2lnbmVkRGF0YSI6IkwweHpHbjYxMitZWW0vTldBQmk5bUwvazhrTEtVWlB3
  QTVtRE5iUXFST3JNb3JDT254MGkvRFVUb1Z6cjR0WHlITDRpL1QvQzNnK3UzdFFSYlhSbXlDenl0
  aFN3ZUEvL0pPTEUxUFFVU0w2bWxoUHR2T3pqSkVoZWcxdHBRZ1Z4NUQyMWczM3FJSFFXd29CWmR6
  MERMd085a2Z0NzNBNXcxNThkdnAxUDBURHV6N096VlplK2trK1hjaFdDeW05cFRPZ2t5a3dvWTd5
  dE9zQmlIK3VHS2NTaWVveEZtcUNES1FIR1Z0VGFIdTVrMHNqcC9IZ2RmZi9aTnliVWpOQUIyOVd0
  MExaTXp3Wi9OcmFXcE9VNW51U2toNitmcFV5a3o3bG14Y0NFNjRRdmdNTFBiODREMWNIUHJNMGpl
  SGc2TC9aeElNMEp0a3MrNWduUmYzQXlHdz09In0='''
      .replaceAll(' ', '')
      .replaceAll('\n', '')
      .replaceAll('\r', ''));
}
