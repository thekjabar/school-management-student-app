import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/ui/phone_field.dart';

TextEditingValue _typed(String text, [int? cursor]) =>
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor ?? text.length));

TextEditingValue _edit(TextEditingValue old, TextEditingValue next) =>
    const IraqiPhoneFormatter().formatEditUpdate(old, next);

void main() {
  group('IraqiPhone.digitsOf', () {
    test('keeps a local number', () {
      expect(IraqiPhone.digitsOf('0750 123 4567'), '07501234567');
    });

    test('folds international forms into the local one', () {
      expect(IraqiPhone.digitsOf('+964 750 123 4567'), '07501234567');
      expect(IraqiPhone.digitsOf('00964 750 123 4567'), '07501234567');
      expect(IraqiPhone.digitsOf('9647501234567'), '07501234567');
      expect(IraqiPhone.digitsOf('7501234567'), '07501234567');
    });

    test('reads Arabic-Indic and Persian digits', () {
      expect(IraqiPhone.digitsOf('٠٧٥٠ ١٢٣ ٤٥٦٧'), '07501234567');
      expect(IraqiPhone.digitsOf('۰۷۵۰۱۲۳۴۵۶۷'), '07501234567');
    });
  });

  group('IraqiPhone.isValid', () {
    test('accepts an Iraqi mobile', () {
      expect(IraqiPhone.isValid('0770 000 0000'), isTrue);
      expect(IraqiPhone.isValid('+9647700000000'), isTrue);
    });

    test('rejects everything else', () {
      expect(IraqiPhone.isValid(''), isFalse);
      expect(IraqiPhone.isValid('0750 123 456'), isFalse);
      expect(IraqiPhone.isValid('066 123 4567'), isFalse);
      expect(IraqiPhone.isValid('00787879788787887979797'), isFalse);
    });
  });

  group('IraqiPhoneFormatter', () {
    test('groups as 07XX XXX XXXX while typing', () {
      final out = _edit(_typed('0750 12'), _typed('0750 123'));
      expect(out.text, '0750 123');
      final more = _edit(_typed('0750 123'), _typed('0750 1234'));
      expect(more.text, '0750 123 4');
      expect(more.selection.baseOffset, more.text.length);
    });

    test('stops at eleven digits', () {
      final old = _typed('0750 123 4567');
      expect(_edit(old, _typed('0750 123 45678')), old);
    });

    test('refuses an over-long paste instead of truncating it', () {
      final old = _typed('');
      expect(_edit(old, _typed('00787879788787887979797')), old);
      expect(_edit(old, _typed('075012345678')), old);
    });

    test('normalises a pasted international number', () {
      expect(_edit(_typed(''), _typed('+964 750 123 4567')).text, '0750 123 4567');
      expect(_edit(_typed(''), _typed('009647501234567')).text, '0750 123 4567');
    });

    test('converts Arabic-Indic digits as they are typed', () {
      expect(_edit(_typed('07'), _typed('07٥')).text, '075');
    });

    test('drops letters and symbols', () {
      expect(_edit(_typed('075'), _typed('075a-')).text, '075');
    });

    test('backspace over a space removes the digit before it', () {
      final old = _typed('0750 1', 5);
      final out = _edit(old, _typed('07501', 4));
      expect(out.text, '0751');
      expect(out.selection.baseOffset, 3);
    });

    test('a leading 7 gains its 0', () {
      final out = _edit(_typed(''), _typed('7'));
      expect(out.text, '07');
      expect(out.selection.baseOffset, 2);
    });
  });
}
