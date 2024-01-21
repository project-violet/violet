// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/cert/cert_data.dart';
import 'package:violet/cert/cert_util.dart';
import 'package:violet/cert/root.dart';

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
  });

  test('Create Cert', () async {
    var pair = CertUtil.createRSAKeyPair();

    var rootCA = RootCert(data: {
      'PubKey': CertUtil.exportRSAPublicKey(pair.item1),
      'AuthStarts': DateTime.now().toUtc().toString(),
      'AuthEnds': DateTime.now()
          .add(const Duration(days: 365 * 20 + 4))
          .toUtc()
          .toString(),
      'AuthVersion': '1.0',
      'Owner': 'koromo the violet project leader',
    });

    var signedData = CertUtil.sign(
        pair.item2, Uint8List.fromList(rootCA.getRawData().codeUnits));

    rootCA.data['SignedData'] = CertUtil.l8ToStr(signedData);

    print('--- Verify ROOT CA ---');
    print(rootCA.verify(rootCA));
    expect(rootCA.verify(rootCA), true);

    print('--- ROOT CA ---');
    print(rootCA.toBase64());

    print('--- ROOT CA RSA PRIVATE KEY ---');
    print(CertUtil.exportRSAPrivateKey(pair.item2));
    print('--- ROOT CA RSA PUBLIC KEY ---');
    print(CertUtil.exportRSAPublicKey(pair.item1));

    var priKey = pair.item2;
    var pubKey = pair.item1;

    var testCert = CertData(data: {
      'PubKey': CertUtil.exportRSAPublicKey(pubKey),
      'AuthStarts': DateTime.now().toUtc().toString(),
      'AuthEnds': DateTime.now()
          .add(const Duration(days: 365 * 10 + 4))
          .toUtc()
          .toString(),
      'AuthVersion': '1.0',
      'Owner': 'test user',
    });

    var testSignedData = CertUtil.sign(
        priKey, Uint8List.fromList(testCert.getRawData().codeUnits));

    testCert.data['SignedData'] = CertUtil.l8ToStr(testSignedData);

    print('--- Verify TEST CERT ---');
    print(testCert.verify(rootCA));
    expect(testCert.verify(rootCA), true);

    print('--- TEST CERT ---');
    print(testCert.toBase64());
  });

  test('Test Root Cert', () async {
    var testCert = CertData.testCert();
    expect(testCert.verify(RootCert.koromoCA()), true);
  });
}
