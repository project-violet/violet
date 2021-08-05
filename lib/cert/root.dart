// This source code is a part of Project Violet.
// Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import 'package:pointycastle/export.dart';
import 'package:violet/cert/cert_data.dart';

class RootCert extends CertData {
  RootCert({Map<String, String> data}) : super(data: data);

  String rsaPublicModulus() => data['RSAPublicModulus'];
  String rsaPublicExponent() => data['RSAPublicExponent'];
}
