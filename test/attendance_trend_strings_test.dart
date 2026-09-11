import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/parent/attendance_screen.dart';

AttendanceTrend _trend(String band, {required int daysMarked}) => AttendanceTrend(
      termId: 'ckterm0000000000000000000',
      termName: 'Second semester',
      from: DateTime(2026, 5, 1),
      to: DateTime(2026, 9, 11),
      present: 6,
      absent: 6,
      late: 1,
      excused: 1,
      leftEarly: 0,
      daysMarked: daysMarked,
      daysMissed: 7,
      missedPercent: 13.2,
      attendanceRate: 84.9,
      band: band,
      expectedSchoolDays: 57,
      byMonth: const [],
      previous: null,
      direction: null,
    );

void main() {
  test('every band says something, in every language, rather than naming its key', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;

      for (final band in ['OK', 'WATCH', 'CONCERN', 'UNKNOWN']) {
        final look = attendanceBand(band);
        final body = attendanceBandBody(
          _trend(band, daysMarked: band == 'UNKNOWN' ? 6 : 53),
          'Shadan',
          'Second semester',
        );

        for (final line in [look.title, body]) {
          expect(
            line,
            isNot(contains('att.')),
            reason: '$band in ${lang.code} would print a raw key: $line',
          );
          expect(
            line,
            isNot(contains('{')),
            reason: '$band in ${lang.code} left a placeholder unfilled: $line',
          );
          expect(line.trim(), isNotEmpty);
        }

        expect(body, contains('Shadan'), reason: 'the child is named in $band / ${lang.code}');
        expect(
          body,
          contains('Second semester'),
          reason: 'the term is captioned from the response in $band / ${lang.code}',
        );
      }
    }

    AppLocale.current.value = Lang.en;
  });

  test('an unnamed term is captioned by its dates, never as "this term"', () {
    AppLocale.current.value = Lang.en;

    final body = attendanceBandBody(
      _trend('WATCH', daysMarked: 53),
      'Shadan',
      '12 Jun – 11 Sep',
    );

    expect(body, contains('12 Jun – 11 Sep'));
    expect(body, isNot(contains('this term')));
  });
}
