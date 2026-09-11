import 'package:flutter/material.dart';

import '../i18n/strings.dart';

String clock(int? minuteOfDay) {
  if (minuteOfDay == null) return '—';
  final h = (minuteOfDay ~/ 60) % 24;
  final m = minuteOfDay % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String clock12(int? minuteOfDay) {
  if (minuteOfDay == null) return '—';
  final h24 = (minuteOfDay ~/ 60) % 24;
  final m = minuteOfDay % 60;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  final suffix = h24 < 12 ? 'AM' : 'PM';
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suffix';
}

String hhmm(DateTime? at) {
  if (at == null) return '—';
  return '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

String _month(int m) => t('month.$m');
String _monthShort(int m) => t('monthShort.$m');
String _day(int weekday) => t('day.$weekday');

String monthYear(DateTime d) => '${_month(d.month)} ${d.year}';

List<String> weekdayInitials() => [
      t('dayInitial.1'),
      t('dayInitial.2'),
      t('dayInitial.3'),
      t('dayInitial.4'),
      t('dayInitial.5'),
      t('dayInitial.6'),
      t('dayInitial.7'),
    ];

String shortDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day} ${_monthShort(d.month)}';
}

String longDate(DateTime? d) {
  if (d == null) return '—';
  return '${_day(d.weekday)} ${d.day} ${_month(d.month)} ${d.year}';
}

String dueWord(int days) {
  if (days < -1) return tn('due.overdue', -days);
  if (days == -1) return t('due.yesterday');
  if (days == 0) return t('due.today');
  if (days == 1) return t('due.tomorrow');
  return tn('due.inDays', days);
}

String humanise(String? value) {
  if (value == null || value.isEmpty) return '—';
  final lower = value.replaceAll('_', ' ').toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

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

Color parseHex(String? hex, Color fallback) {
  if (hex == null || hex.length < 7) return fallback;
  final value = int.tryParse(hex.substring(1), radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}

String weekdayName(String apiWeekday) {
  const order = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  final i = order.indexOf(apiWeekday.toUpperCase());
  return i == -1 ? apiWeekday : t('day.${i + 1}');
}

String todayWeekday() {
  const names = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY',
  ];
  return names[DateTime.now().weekday - 1];
}
