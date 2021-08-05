// This source code is a part of Project Violet.
// Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:violet/cert/cert_util.dart';
import 'package:violet/cert/root.dart';

class CertData {
  Map<String, String> data;
  CertData({this.data});

  DateTime authStarts() => DateTime.parse(data['AuthStarts']).toLocal();
  DateTime authEnds() => DateTime.parse(data['AuthEnds']).toLocal();
  String authVersion() => data['AuthVersion'];
  String owner() => data['Owner']; // UserAppId

  String signedData() => data['SignedData'];

  String getRawData() =>
      "${data['AuthStarts']}|${data['AuthEnds']}|${data['AuthVersion']}|${data['Owner']}";

  bool verify(RootCert rootCA) {
    var rawData = getRawData();
    var rsaPub = RSAPublicKey(BigInt.parse(rootCA.rsaPublicModulus()),
        BigInt.parse(rootCA.rsaPublicExponent()));

    return CertUtil.verify(rsaPub, Uint8List.fromList(rawData.codeUnits),
        base64.decode(signedData()));
  }
}
