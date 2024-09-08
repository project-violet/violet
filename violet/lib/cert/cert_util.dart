// This source code is a part of Project Violet.
// Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

// https://github.com/bcgit/pc-dart/blob/master/tutorials/rsa.md
class CertUtil {
  static (RSAPublicKey, RSAPrivateKey) createRSAKeyPair() {
    final secureRandom = SecureRandom('Fortuna')
      ..seed(KeyParameter(Uint8List.fromList(
          List.generate(32, (index) => Random().nextInt(256)))));
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          secureRandom));
    final pair = keyGen.generateKeyPair();

    return (pair.publicKey as RSAPublicKey, pair.privateKey as RSAPrivateKey);
  }

  static Uint8List sign(RSAPrivateKey privateKey, Uint8List dataToSign) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(
        true, PrivateKeyParameter<RSAPrivateKey>(privateKey)); // true=sign
    final sig = signer.generateSignature(dataToSign);
    return sig.bytes;
  }

  static bool verify(
      RSAPublicKey publicKey, Uint8List signedData, Uint8List signature) {
    final sig = RSASignature(signature);
    final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');

    verifier.init(
        false, PublicKeyParameter<RSAPublicKey>(publicKey)); // false=verify

    try {
      return verifier.verifySignature(signedData, sig);
    } on ArgumentError {
      return false; // for Pointy Castle 1.0.2 when signature has been modified
    }
  }

  static Uint8List strTol8(String value) {
    return base64.decode(value);
  }

  static String l8ToStr(Uint8List value) => base64.encode(value);

  static String exportRSAPublicKey(RSAPublicKey publicKey) {
    return utf8.fuse(base64).encode(jsonEncode({
          'exponent': publicKey.exponent.toString(),
          'modulus': publicKey.modulus.toString(),
        }));
  }

  static RSAPublicKey importRSAPublicKey(String key) {
    var map = jsonDecode(utf8.fuse(base64).decode(key)) as Map<String, dynamic>;

    return RSAPublicKey(
      BigInt.parse(map['modulus']),
      BigInt.parse(map['exponent']),
    );
  }

  static String exportRSAPrivateKey(RSAPrivateKey privateKey) {
    return utf8.fuse(base64).encode(jsonEncode({
          'p': privateKey.p.toString(),
          'q': privateKey.q.toString(),
          'exponent': privateKey.privateExponent.toString(),
          'modulus': privateKey.modulus.toString(),
        }));
  }

  static RSAPrivateKey importRSAPrivateKey(String key) {
    var map = jsonDecode(utf8.fuse(base64).decode(key)) as Map<String, dynamic>;

    return RSAPrivateKey(
      BigInt.parse(map['modulus']),
      BigInt.parse(map['exponent']),
      BigInt.parse(map['p']),
      BigInt.parse(map['q']),
    );
  }
}
