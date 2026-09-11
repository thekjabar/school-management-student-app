import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/ui/format.dart';

const medicalFlags = <String>[
  'ASTHMA',
  'SEVERE_ALLERGY_ANAPHYLAXIS',
  'EPILEPSY_SEIZURES',
  'DIABETES',
  'CARDIAC',
  'HEAT_SENSITIVE',
  'MOBILITY_IMPAIRMENT',
  'VISION_IMPAIRMENT',
  'HEARING_IMPAIRMENT',
  'COMMUNICATION_SUPPORT',
  'MEDICATION_CARRIED',
  'OTHER',
];

void main() {
  test('every medical flag the server can send has a label in every language', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      for (final flag in medicalFlags) {
        final key = 'medFlag.$flag';
        expect(
          tableFor(lang).containsKey(key),
          isTrue,
          reason: '$key is missing from ${lang.code}, so the card shows the raw code',
        );
        final label = tOr(key, humanise(flag));
        expect(label, isNot(key), reason: '$key rendered as itself in ${lang.code}');
        expect(label.trim(), isNotEmpty, reason: '$key is blank in ${lang.code}');
      }
    }
  });

  test('Kurdish and Arabic do not carry the English wording', () {
    for (final flag in medicalFlags) {
      final key = 'medFlag.$flag';
      final english = tableFor(Lang.en)[key];
      expect(tableFor(Lang.ckb)[key], isNot(english), reason: '$key is still English in ckb');
      expect(tableFor(Lang.ar)[key], isNot(english), reason: '$key is still English in ar');
    }
  });

  test('a flag added to the server later reads as words, never as a key', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      expect(
        tOr('medFlag.NOT_YET_TRANSLATED', humanise('NOT_YET_TRANSLATED')),
        'Not yet translated',
      );
    }
  });
}
