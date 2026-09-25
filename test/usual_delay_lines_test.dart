import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/parent/bus_screen.dart';

void main() {
  setUp(() => AppLocale.current.value = Lang.en);

  const sunday = 7;

  test('a real delay on today\'s weekday becomes one plain sentence per run', () {
    final lines = usualDelayLines(const [
      DelayDay(morning: true, weekday: sunday, minutes: 7, trips: 8),
      DelayDay(morning: false, weekday: sunday, minutes: -4, trips: 6),
      DelayDay(morning: true, weekday: 1, minutes: 12, trips: 8),
    ], sunday);
    expect(lines.map((l) => l.text), [
      tv('delay.lateOut', {'day': t('day.$sunday'), 'n': 7}),
      tv('delay.earlyReturn', {'day': t('day.$sunday'), 'n': 4}),
    ]);
  });

  test('a delay too small to matter says nothing', () {
    expect(usualDelayLines(const [DelayDay(morning: true, weekday: sunday, minutes: 2, trips: 9)], sunday), isEmpty);
  });

  test('the sentences exist in Kurdish and Arabic', () {
    for (final lang in [Lang.ckb, Lang.ar]) {
      AppLocale.current.value = lang;
      final text = usualDelayLines(const [DelayDay(morning: true, weekday: sunday, minutes: 7, trips: 8)], sunday).single.text;
      expect(text, isNot(contains('delay.')));
      expect(text, contains(t('day.$sunday')));
    }
  });
}
