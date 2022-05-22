// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

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
    var trans = Localizations.of<Translations>(context, Translations);
    if (trans != null)
      return Localizations.of<Translations>(context, Translations)!;
    else
      return instance!;
  }

  late Map<String, String> _sentences;

  late String dbLanguageCode;

  Future<bool> load([String? code]) async {
    if (code == null) {
      code = locale.languageCode;
      dbLanguageCode = code;
      if (!code.contains('_')) {
        if (locale.scriptCode != null && locale.scriptCode != '')
          code += '_' + this.locale.scriptCode!;
      }
    } else if (code.contains('_')) {
      dbLanguageCode = code.split('_')[0];
    } else {
      dbLanguageCode = code;
    }

    print(code);

    String data = await rootBundle.loadString('assets/locale/$code.json');
    Map<String, dynamic> _result = json.decode(data);

    this._sentences = Map();
    _result.forEach((String key, dynamic value) {
      this._sentences[key] = value.toString();
    });

    instance = this;

    return true;
  }

  String trans(String key) {
    return this._sentences[key]!;
  }
}

class TranslationsDelegate extends LocalizationsDelegate<Translations> {
  const TranslationsDelegate();

  @override
  bool isSupported(Locale locale) {
    var lc = ['ko', 'en', 'ja', 'zh', 'it', 'eo'].contains(locale.languageCode);
    var sc = ['Hans', 'Hant'].contains(locale.scriptCode);
    if (locale.languageCode == 'zh') {
      return sc;
    }
    return lc || sc;
  }

  @override
  Future<Translations> load(Locale locale) async {
    Translations localizations = Translations(locale);
    await localizations.load();

    if (Translations.instance == null) {
      await localizations.load('en');
    }

    print("Load ${locale.languageCode}");

    return localizations;
  }

  @override
  bool shouldReload(TranslationsDelegate old) => false;
}
