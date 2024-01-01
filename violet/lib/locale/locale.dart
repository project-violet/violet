// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Translations {
  Translations(this.locale);

  Locale locale;

  // Latest instance
  static Translations? instance;

  static Translations of(BuildContext context) {
    final trans = Localizations.of<Translations>(context, Translations);

    if (trans != null) {
      return trans;
    } else {
      return instance!;
    }
  }

  bool isSupported() {
    final lc =
        ['ko', 'en', 'ja', 'zh', 'it', 'eo'].contains(locale.languageCode);
    final sc = ['Hans', 'Hant'].contains(locale.scriptCode);
    if (locale.languageCode == 'zh') {
      return sc;
    }
    return lc;
  }

  late Map<String, String> _sentences;

  late String dbLanguageCode;

  Future<bool> load([String? code]) async {
    if (code == null) {
      code = locale.languageCode;
      dbLanguageCode = code;
      if (!code.contains('_')) {
        if (locale.scriptCode != null && locale.scriptCode != '') {
          code += '_${locale.scriptCode!}';
        }
      }
    } else if (code.contains('_')) {
      dbLanguageCode = code.split('_')[0];
    } else {
      dbLanguageCode = code;
    }

    if (!isSupported()) {
      if (locale.languageCode == 'zh') {
        dbLanguageCode = 'zh_Hans';
      } else {
        dbLanguageCode = 'en';
      }
    }

    String data = await rootBundle.loadString('assets/locale/$code.json');
    Map<String, dynamic> result = json.decode(data);

    _sentences = {};
    result.forEach((String key, dynamic value) {
      _sentences[key] = value.toString();
    });

    instance = this;

    return true;
  }

  String trans(String key) {
    return _sentences[key] ?? key;
  }
}

class TranslationsDelegate extends LocalizationsDelegate<Translations> {
  const TranslationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return true;
  }

  @override
  Future<Translations> load(Locale locale) async {
    Translations localizations = Translations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(TranslationsDelegate old) => false;
}
