// Checks that the three languages actually say the same things.
//
// A missing key falls back to English rather than showing the key, which is the
// right behaviour on a phone and the wrong one for anybody trying to find the
// gap: the screen looks fine and one line is quietly in the wrong language.
// This is what finds them.
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/i18n/strings.dart';

void main() {
  test('every language carries every phrase', () {
    final missing = <String, List<String>>{};

    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      final gaps = <String>[];
      for (final key in englishKeys) {
        // t() falls back to English, so compare against the raw table.
        if (!tableFor(lang).containsKey(key)) gaps.add(key);
      }
      if (gaps.isNotEmpty) missing[lang.code] = gaps;
    }

    expect(
      missing,
      isEmpty,
      reason: 'untranslated keys:\n${missing.entries.map((e) => '  ${e.key}: ${e.value.join(', ')}').join('\n')}',
    );
  });

  test('no language carries a phrase the others do not', () {
    for (final lang in Lang.values) {
      final extra = tableFor(lang).keys.where((k) => !englishKeys.contains(k)).toList();
      expect(extra, isEmpty, reason: '${lang.code} has keys English does not: $extra');
    }
  });

  test('placeholders survive translation', () {
    // A phrase with {n} in English must keep it in every language, or the
    // number simply vanishes from the sentence.
    for (final key in englishKeys) {
      if (!(tableFor(Lang.en)[key] ?? '').contains('{n}')) continue;
      for (final lang in Lang.values) {
        expect(
          tableFor(lang)[key],
          contains('{n}'),
          reason: '$key lost its {n} in ${lang.code}',
        );
      }
    }
  });

  test('nothing is left as an empty string', () {
    for (final lang in Lang.values) {
      tableFor(lang).forEach((key, value) {
        expect(value.trim(), isNotEmpty, reason: '$key is blank in ${lang.code}');
      });
    }
  });
}
