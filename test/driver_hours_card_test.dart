import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/crew_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/driver/hours_card.dart';

Map<String, dynamic> _payload({
  String standing = 'OK',
  bool breakDue = false,
  int minutesUntilBreakDue = 95,
  int drivingMinutesToday = 62,
  int currentDrivingStretchMinutes = 62,
  int dutyMinutesThisWeek = 180,
  bool onDutyNow = true,
  String enforcement = 'BLOCK',
  List<Map<String, dynamic>> over = const [],
  List<Map<String, dynamic>> nearing = const [],
}) =>
    {
      'measuredAt': '2026-09-22T06:00:00.000Z',
      'timezone': 'Asia/Baghdad',
      'enforcement': enforcement,
      'standing': standing,
      'breakDue': breakDue,
      'minutesUntilBreakDue': minutesUntilBreakDue,
      'drivingMinutesToday': drivingMinutesToday,
      'dutyMinutesToday': drivingMinutesToday,
      'dutyMinutesThisWeek': dutyMinutesThisWeek,
      'currentDrivingStretchMinutes': currentDrivingStretchMinutes,
      'longestDrivingStretchMinutes': currentDrivingStretchMinutes,
      'restMinutesSinceLastDuty': null,
      'longestRestMinutesInLastDay': 120,
      'onDutyNow': onDutyNow,
      'limits': {
        'maxContinuousDrivingMinutes': 240,
        'breakMinutes': 30,
        'maxDutyMinutesPerDay': 540,
        'minDailyRestMinutes': 660,
        'maxDutyMinutesPerWeek': 600,
        'warnPercent': 85,
      },
      'over': over,
      'nearing': nearing,
    };

DrivingHours _tired({String enforcement = 'BLOCK'}) => DrivingHours.fromJson(_payload(
      standing: 'OVER',
      breakDue: true,
      minutesUntilBreakDue: 0,
      drivingMinutesToday: 245,
      currentDrivingStretchMinutes: 245,
      dutyMinutesThisWeek: 610,
      enforcement: enforcement,
      over: const [
        {'rule': 'CONTINUOUS_DRIVING', 'minutes': 245, 'limit': 240}
      ],
    ));

Future<void> _pump(WidgetTester tester, Lang lang, DrivingHours hours) async {
  AppLocale.current.value = lang;
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: lang.direction,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: HoursPanel(hours: hours),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('hours arrive as a clock reading, not as raw minutes', () {
    expect(hoursClock(245), '4:05');
    expect(hoursClock(60), '1:00');
    expect(hoursClock(0), '0:00');
    expect(hoursClock(-5), '0:00');
  });

  test('the limits and the broken rules survive the journey from the server', () {
    final h = _tired();
    expect(h.past, isTrue);
    expect(h.breakDue, isTrue);
    expect(h.over, ['CONTINUOUS_DRIVING']);
    expect(h.maxContinuousDrivingMinutes, 240);
    expect(h.breakMinutes, 30);
    expect(h.maxDutyMinutesPerWeek, 600);
    expect(h.stopsTrips, isTrue);
  });

  test('a driver well inside the limits and off duty is not nagged', () {
    final rested = DrivingHours.fromJson(_payload(onDutyNow: false));
    expect(hoursWorthShowing(rested), isFalse);
    expect(hoursWorthShowing(DrivingHours.fromJson(_payload())), isTrue);
    expect(hoursWorthShowing(DrivingHours.fromJson(_payload(standing: 'WARNING', onDutyNow: false))), isTrue);
    expect(hoursWorthShowing(_tired()), isTrue);
  });

  test('a school that only warns does not promise the trip will be stopped', () {
    AppLocale.current.value = Lang.en;
    expect(hoursHeadline(_tired()), t('driver.hours.overBlocks'));
    expect(hoursHeadline(_tired(enforcement: 'WARN')), t('driver.hours.overWarns'));
    expect(hoursHeadline(DrivingHours.fromJson(_payload(standing: 'WARNING'))), t('driver.hours.close'));
    expect(hoursHeadline(DrivingHours.fromJson(_payload())), t('driver.hours.ok'));
  });

  testWidgets('a driver over the limit is told plainly, in his own language', (tester) async {
    for (final lang in Lang.values) {
      await _pump(tester, lang, _tired());
      expect(find.text(t('driver.hours.title')), findsOneWidget);
      expect(find.text(t('driver.hours.overBlocks')), findsOneWidget);
      expect(find.text(tn('driver.hours.breakNow', 30)), findsOneWidget);
      expect(find.text('4:05'), findsWidgets);
      expect(find.text('10:10'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a driver still inside the limits is told when the break falls due', (tester) async {
    await _pump(tester, Lang.en, DrivingHours.fromJson(_payload()));
    expect(find.text(tn('driver.hours.breakIn', '1:35')), findsOneWidget);
    expect(find.text(t('driver.hours.ok')), findsOneWidget);
    expect(find.text(tn('driver.hours.breakNow', 30)), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
