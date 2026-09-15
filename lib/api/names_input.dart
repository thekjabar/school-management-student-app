import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../i18n/strings.dart';
import 'family_payments.dart' show LocalText;

abstract final class NameScript {
  static const _arabicLetter =
      r'ؠ-يٮ-ۓەۮۯۺ-ۼݐ-ݿࢠ-ࣉﭐ-﷿ﹰ-ﻼ';
  static const _arabicBlock = r'؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-ﻼ';
  static const _latinLetter = r'A-Za-zÀ-ɏ';

  static final _arabicName =
      RegExp('^(?=.*[$_arabicLetter])[$_arabicBlock\\u200c\\u200d\\s\'\\u2019.\\-]+\$');
  static final _latinName = RegExp('^(?=.*[$_latinLetter])[$_latinLetter\\s\'\\u2019.\\-]+\$');
  static final _arabicText = RegExp('^(?=.*[$_arabicLetter])[^$_latinLetter]+\$');
  static final _latinText =
      RegExp('^(?=.*[$_latinLetter])[^\\u0600-\\u06ff\\u0750-\\u077f\\u08a0-\\u08ff\\ufb50-\\ufdff\\ufe70-\\ufeff]+\$');

  static bool isArabicName(String value) => _arabicName.hasMatch(value.trim());
  static bool isEnglishName(String value) => _latinName.hasMatch(value.trim());
  static bool isArabicText(String value) => _arabicText.hasMatch(value.trim());
  static bool isEnglishText(String value) => _latinText.hasMatch(value.trim());

  static bool textFits(Lang lang, String value) => switch (lang) {
        Lang.ckb => value.trim().isNotEmpty && !isEnglishText(value),
        Lang.ar => isArabicText(value),
        Lang.en => isEnglishText(value),
      };

  static Lang slotForText(Lang reading, String value) {
    if (textFits(reading, value)) return reading;
    if (isEnglishText(value)) return Lang.en;
    return Lang.ckb;
  }
}

class AddressGeocoder {
  AddressGeocoder({
    http.Client? client,
    this.spacing = const Duration(seconds: 1),
    DateTime Function()? clock,
    Future<void> Function(Duration)? pause,
  })  : _client = client,
        _clock = clock ?? DateTime.now,
        _pause = pause ?? Future<void>.delayed;

  static AddressGeocoder instance = AddressGeocoder();

  static const userAgent = 'KSP/1.0 (com.kurdistanstudentprotection.ksp)';
  static const maxLength = 400;

  final http.Client? _client;
  final Duration spacing;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _pause;

  final Map<String, String?> _cache = {};
  DateTime? _lastRequest;
  Future<void> _line = Future<void>.value();

  Future<LocalText> at(double lat, double lon) async {
    final ckb = await _inLanguage(lat, lon, Lang.ckb);
    final ar = await _inLanguage(lat, lon, Lang.ar);
    final en = await _inLanguage(lat, lon, Lang.en);
    return LocalText(ckb: ckb, ar: ar, en: en);
  }

  Future<String?> _inLanguage(double lat, double lon, Lang lang) {
    final key = '${lang.code}:${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
    if (_cache.containsKey(key)) return Future.value(_cache[key]);

    final turn = _line.then((_) => _fetch(lat, lon, lang, key));
    _line = turn.then<void>((_) {}, onError: (_) {});
    return turn;
  }

  Future<String?> _fetch(double lat, double lon, Lang lang, String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    await _waitForTurn();
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$lat',
        'lon': '$lon',
        'format': 'jsonv2',
        'zoom': '18',
        'accept-language': acceptLanguage(lang),
      });
      final headers = {'User-Agent': userAgent};
      final client = _client;
      final res = await (client == null ? http.get(uri, headers: headers) : client.get(uri, headers: headers))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map) return null;
      final text = composeAddress(lang, body['display_name']);
      _cache[key] = text;
      return text;
    } catch (_) {
      return null;
    }
  }

  Future<void> _waitForTurn() async {
    final last = _lastRequest;
    if (last != null) {
      final gap = spacing - _clock().difference(last);
      if (gap > Duration.zero) await _pause(gap);
    }
    _lastRequest = _clock();
  }

  static String acceptLanguage(Lang lang) => switch (lang) {
        Lang.ckb => 'ckb',
        Lang.ar => 'ar',
        Lang.en => 'en',
      };

  static String? composeAddress(Lang lang, Object? displayName) {
    if (displayName is! String) return null;
    final parts = displayName
        .split(RegExp(r'[,،]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && RegExp(r'[^\d\s\-]').hasMatch(p))
        .where((p) => NameScript.textFits(lang, p))
        .take(3)
        .toList();
    if (parts.isEmpty) return null;
    final joined = parts.join(lang == Lang.en ? ', ' : '، ');
    return joined.length > maxLength ? joined.substring(0, maxLength).trim() : joined;
  }
}

const Map<Lang, String> _addressKeys = {Lang.ckb: 'address', Lang.ar: 'addressAr', Lang.en: 'addressEn'};
const Map<Lang, String> _noteKeys = {Lang.ckb: 'note', Lang.ar: 'noteAr', Lang.en: 'noteEn'};

Map<String, Object> homeAddressBody({
  required Lang reading,
  double? lat,
  double? lon,
  required String address,
  required String addressShown,
  required String note,
  required String noteShown,
  LocalText stored = LocalText.empty,
  LocalText geocoded = LocalText.empty,
  bool pinMoved = false,
}) {
  final body = <String, Object>{
    if (lat != null && lon != null) 'lat': lat,
    if (lat != null && lon != null) 'lon': lon,
  };

  for (final lang in Lang.values) {
    final found = geocoded.inLang(lang)?.trim();
    if (found == null || found.isEmpty || !NameScript.textFits(lang, found)) continue;
    if (!pinMoved && stored.inLang(lang) != null) continue;
    body[_addressKeys[lang]!] = found;
  }

  _takeTyped(body, _addressKeys, reading, address, addressShown);
  _takeTyped(body, _noteKeys, reading, note, noteShown);
  return body;
}

void _takeTyped(Map<String, Object> body, Map<Lang, String> keys, Lang reading, String typed, String shown) {
  final text = typed.trim();
  if (text == shown.trim()) return;
  if (text.isEmpty) {
    body[keys[reading]!] = '';
    return;
  }
  body[keys[NameScript.slotForText(reading, text)]!] = text;
}

String? profileNameScriptError(Map<String, String> parts) {
  for (final entry in parts.entries) {
    final value = entry.value.trim();
    if (value.isEmpty) continue;
    if (entry.key.endsWith('Ar') && !NameScript.isArabicName(value)) return 'personal.arabicLettersOnly';
    if (entry.key.endsWith('En') && !NameScript.isEnglishName(value)) return 'personal.englishLettersOnly';
  }
  return null;
}
