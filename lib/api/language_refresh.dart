import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../i18n/strings.dart';
import 'client.dart';
import 'parent_api.dart';
import 'session.dart';

class LanguageRefresh {
  LanguageRefresh._();

  static Future<void> apply(Lang lang) async {
    final renewing = Entitlements.instance.renew();
    await _tellServer(lang);
    await Future.wait([_refreshMe(), renewing]);
  }

  static Future<void> _tellServer(Lang lang) async {
    if (!ApiClient.instance.hasSession) return;
    try {
      await Session.instance.setLocale(lang);
    } on ApiException catch (e) {
      debugPrint('language: the server was not told about ${lang.code}: $e');
    }
  }

  static Future<void> _refreshMe() async {
    if (Session.instance.me == null) return;
    try {
      await Session.instance.refresh();
    } on ApiException catch (e) {
      debugPrint('language: the account was not reloaded in the new language: $e');
    }
  }
}
