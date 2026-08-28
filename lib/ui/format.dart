import 'package:flutter/material.dart';

import '../i18n/strings.dart';

/// Formatting the three apps share.
///
/// One place, because the alternative is each screen inventing its own and a
/// time reading one way on the driver's manifest and another on the parent's
/// bus card for the same journey — which makes both look wrong.

/// A clock time from minutes past midnight.
///
/// Lesson and departure times are stored this way rather than as timestamps,
/// because "period 3 starts at 09:50" is a fact about the school week and not
/// about any particular Tuesday.
String clock(int? minuteOfDay) {
  if (minuteOfDay == null) return '—';
  final h = (minuteOfDay ~/ 60) % 24;
  final m = minuteOfDay % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// The clock part of an instant, which is all a bus card needs.
String hhmm(DateTime? at) {
  if (at == null) return '—';
  return '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String shortDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day} ${_months[d.month - 1]}';
}

String longDate(DateTime? d) {
  if (d == null) return '—';
  return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "in 3 days", "today", "2 days late" — the thing the reader actually wanted
/// to know, rather than a date they have to subtract from today's.
String dueWord(int days) {
  if (days < -1) return tn('due.overdue', -days);
  if (days == -1) return t('due.yesterday');
  if (days == 0) return t('due.today');
  if (days == 1) return t('due.tomorrow');
  return tn('due.inDays', days);
}

/// SCREAMING_ENUM → "screaming enum", for the handful of labels the API sends
/// as enums because they are also part of its contract.
String humanise(String? value) {
  if (value == null || value.isEmpty) return '—';
  final lower = value.replaceAll('_', ' ').toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

/// Iraqi dinars, with no decimal places ever: the smallest note in daily
/// circulation is 250 IQD, so ".00" is two characters pretending to be
/// precision.
String iqd(num? amount) {
  if (amount == null) return '—';
  final whole = amount.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '${buffer.toString()} IQD';
}

/// A colour the API sent as "#c2410c", or a fallback.
Color parseHex(String? hex, Color fallback) {
  if (hex == null || hex.length < 7) return fallback;
  final value = int.tryParse(hex.substring(1), radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}

/// The weekday the school is on right now, in the API's own vocabulary.
String todayWeekday() {
  const names = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY',
  ];
  return names[DateTime.now().weekday - 1];
}
