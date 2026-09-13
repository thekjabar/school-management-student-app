import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/strings.dart';

abstract final class IraqiPhone {
  static const length = 11;

  static final _mobile = RegExp(r'^07\d{9}$');
  static final _easternDigit = RegExp('[٠-٩۰-۹]');
  static final _nonDigit = RegExp(r'\D');

  static String latinDigits(String raw) => raw.replaceAllMapped(_easternDigit, (m) {
        final unit = m[0]!.codeUnitAt(0);
        final zero = unit >= 0x06F0 ? 0x06F0 : 0x0660;
        return String.fromCharCode(0x30 + unit - zero);
      });

  static String digitsOf(String raw) {
    var d = latinDigits(raw).replaceAll(_nonDigit, '');
    if (d.startsWith('00964') && d.length > 5) {
      d = d.substring(5);
    } else if (d.startsWith('964') && d.length > 3) {
      d = d.substring(3);
    }
    if (d.startsWith('7')) d = '0$d';
    return d;
  }

  static bool isValid(String raw) => _mobile.hasMatch(digitsOf(raw));

  static String grouped(String digits) {
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 4 || i == 7) out.write(' ');
      out.write(digits[i]);
    }
    return out.toString();
  }

  static String display(String raw) {
    final d = digitsOf(raw);
    return grouped(d.length > length ? d.substring(0, length) : d);
  }
}

class IraqiPhoneFormatter extends TextInputFormatter {
  const IraqiPhoneFormatter();

  static final _digit = RegExp(r'\d');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = IraqiPhone.latinDigits(newValue.text);
    var cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, text.length)
        : text.length;
    var raw = text.replaceAll(RegExp(r'\D'), '');
    var before = _digitsBefore(text, cursor);

    final removedSeparator = newValue.selection.isCollapsed &&
        text.length < oldValue.text.length &&
        raw == IraqiPhone.latinDigits(oldValue.text).replaceAll(RegExp(r'\D'), '');
    if (removedSeparator && before > 0) {
      raw = raw.substring(0, before - 1) + raw.substring(before);
      before -= 1;
    }

    final digits = IraqiPhone.digitsOf(raw);
    if (digits.length > IraqiPhone.length) return oldValue;

    final shaped = IraqiPhone.grouped(digits);
    if (digits == raw) {
      cursor = _offsetAfterDigits(shaped, before);
    } else if (digits == '0$raw') {
      cursor = _offsetAfterDigits(shaped, before + 1);
    } else {
      cursor = shaped.length;
    }
    return TextEditingValue(
      text: shaped,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  static int _digitsBefore(String text, int offset) =>
      _digit.allMatches(text.substring(0, offset)).length;

  static int _offsetAfterDigits(String shaped, int count) {
    if (count <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < shaped.length; i++) {
      if (_digit.hasMatch(shaped[i])) seen++;
      if (seen == count) return i + 1;
    }
    return shaped.length;
  }
}

class PhoneTextField extends StatelessWidget {
  const PhoneTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.style,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextStyle? style;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        keyboardType: TextInputType.phone,
        textInputAction: textInputAction,
        autofillHints: const [AutofillHints.telephoneNumber],
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: const [IraqiPhoneFormatter()],
        onSubmitted: onSubmitted,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
        style: style,
        decoration: decoration.copyWith(
          hintText: t('phone.hint'),
          hintTextDirection: TextDirection.ltr,
        ),
      );
}
