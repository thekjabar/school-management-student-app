// Day and month names are written, never cut.
//
// Six screens used to render a date label as `t('day.$n').characters.take(3)`.
// In English that yields "Sep" and looks deliberate. In Kurdish and Arabic it
// takes three letters off the front of a word: هەینی — Friday — reached the
// calendar as هەی, which is not a word, and the office could not tell which day
// the column was. Slicing is not how either script abbreviates.
//
// So there are two sets of phrases now, both written out in each language: the
// whole word, and a short form. A screen picks one. Nothing derives one from
// the other, and these tests are what keep it that way.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/i18n/strings.dart';

/// Every `.dart` file under lib/, so the source itself can be checked.
final _sources = <String, String>{};

void main() {
  setUpAll(() {
    // Resolved from the package root, which is where `flutter test` runs.
    void walk(String dir) {
      for (final entry in Directory(dir).listSync(recursive: true)) {
        if (entry is File && entry.path.endsWith('.dart')) {
          _sources[entry.path] = entry.readAsStringSync();
        }
      }
    }

    walk('lib');
  });

  test('every language carries a whole name and a short one for each day and month', () {
    for (final lang in Lang.values) {
      final table = tableFor(lang);
      for (var d = 1; d <= 7; d++) {
        expect(table['day.$d'], isNotNull, reason: '${lang.code}: day.$d is missing');
        expect(table['dayShort.$d'], isNotNull, reason: '${lang.code}: dayShort.$d is missing');
      }
      for (var m = 1; m <= 12; m++) {
        expect(table['month.$m'], isNotNull, reason: '${lang.code}: month.$m is missing');
        expect(table['monthShort.$m'], isNotNull, reason: '${lang.code}: monthShort.$m is missing');
      }
    }
  });

  test('no screen cuts a date name to a fixed number of characters', () {
    final offenders = <String>[];
    for (final entry in _sources.entries) {
      final lines = entry.value.split('\n');
      for (var i = 0; i < lines.length; i++) {
        // The call was often split across lines, so look at a small window.
        final window = lines.skip(i).take(4).join(' ');
        final looksLikeADate = window.contains("t('day.") ||
            window.contains("t('month.") ||
            window.contains("t('dayShort.") ||
            window.contains("t('monthShort.");
        if (looksLikeADate && window.contains('characters.take')) {
          offenders.add('${entry.key}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'these cut a translated date name to a fixed length:\n  ${offenders.join('\n  ')}');
  });

  test('the Kurdish week reads as Kurdish words', () {
    final ckb = tableFor(Lang.ckb);
    // The one the office reported: هەینی, not هەی.
    expect(ckb['day.5'], 'هەینی');
    expect(ckb['dayShort.5'], 'هەینی');
    // Five of the seven are "<number>شەممە" and must say so in full.
    expect(ckb['day.1'], 'دووشەممە');
    expect(ckb['day.2'], 'سێشەممە');
    expect(ckb['day.3'], 'چوارشەممە');
    expect(ckb['day.4'], 'پێنجشەممە');
    expect(ckb['day.6'], 'شەممە');
    expect(ckb['day.7'], 'یەکشەممە');
  });

  test('the Arabic week reads as Arabic words', () {
    final ar = tableFor(Lang.ar);
    expect(ar['day.1'], 'الاثنين');
    expect(ar['day.2'], 'الثلاثاء');
    expect(ar['day.3'], 'الأربعاء');
    expect(ar['day.4'], 'الخميس');
    expect(ar['day.5'], 'الجمعة');
    expect(ar['day.6'], 'السبت');
    expect(ar['day.7'], 'الأحد');
  });

  test('each short form is a word somebody would actually write', () {
    // Asserted one by one rather than by a rule, because the obvious rule —
    // "a short form must not be the start of the long one" — is wrong here.
    // دوو IS the start of دووشەممە, and is also the correct short form: five of
    // the seven Kurdish weekdays are "<number>شەممە" and the number alone is
    // how they are said. What made هەی wrong was not that it was a prefix but
    // that it was a fragment — هەینی carries no number to fall back on, so it
    // is written whole. No rule separates those two cases; a person does, once,
    // here.
    final ckb = tableFor(Lang.ckb);
    expect(ckb['dayShort.1'], 'دوو');
    expect(ckb['dayShort.2'], 'سێ');
    expect(ckb['dayShort.3'], 'چوار');
    expect(ckb['dayShort.4'], 'پێنج');
    expect(ckb['dayShort.5'], 'هەینی');
    expect(ckb['dayShort.6'], 'شەممە');
    expect(ckb['dayShort.7'], 'یەک');

    final ar = tableFor(Lang.ar);
    expect(ar['dayShort.1'], 'إثنين');
    expect(ar['dayShort.2'], 'ثلاثاء');
    expect(ar['dayShort.3'], 'أربعاء');
    expect(ar['dayShort.4'], 'خميس');
    expect(ar['dayShort.5'], 'جمعة');
    expect(ar['dayShort.6'], 'سبت');
    expect(ar['dayShort.7'], 'أحد');
  });

  test('no month name is a fragment', () {
    // The Kurdish and Arabic months were stored as ک٢, ئاز, ئەی, تش١ and ينا,
    // فبر, أكت — cut to fit, and unreadable. Every one of them is now either
    // the whole name or, for the four that are two words, the name with its
    // own numeral.
    for (final lang in [Lang.ckb, Lang.ar]) {
      final table = tableFor(lang);
      for (var m = 1; m <= 12; m++) {
        expect(table['month.$m']!.length, greaterThanOrEqualTo(2),
            reason: '${lang.code}: month.$m is too short to be a name');
        expect(table['monthShort.$m']!.length, greaterThanOrEqualTo(2),
            reason: '${lang.code}: monthShort.$m is too short to be a name');
      }
    }
  });
}
