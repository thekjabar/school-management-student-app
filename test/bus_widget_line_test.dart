import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/bus_widget.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/ui/format.dart';

LiveBus _bus({
  bool visible = true,
  String? reason,
  bool stale = false,
  int? eta,
  String? state,
  DateTime? alightedAt,
}) =>
    LiveBus(
      studentId: 'cmstudentwidget000000001',
      studentName: 'Ari Hawre Ahmed',
      visible: visible,
      reason: reason,
      lat: visible ? 36.19 : null,
      lon: visible ? 44.01 : null,
      ageSeconds: 20,
      stale: stale,
      stopName: null,
      etaMinutes: eta,
      stopLat: null,
      stopLon: null,
      childState: state,
      boardedAt: null,
      alightedAt: alightedAt,
      headingDeg: null,
      speedKph: null,
      busLabel: null,
      plate: null,
      driverName: null,
      simulated: false,
    );

void main() {
  setUp(() => AppLocale.current.value = Lang.en);

  test('a coming bus says how many minutes, and it is live', () {
    final line = busWidgetLine(_bus(eta: 6));
    expect(line.name, 'Ari');
    expect(line.id, 'cmstudentwidget000000001');
    expect(line.line, tn('widget.arrivesIn', 6));
    expect(line.live, isTrue);
  });

  test('a bus at the pickup point says so', () {
    expect(busWidgetLine(_bus(eta: 0)).line, t('widget.atPickup'));
  });

  test('a child on the bus, and a child already dropped off, are not live countdowns', () {
    final onBoard = busWidgetLine(_bus(eta: 4, state: 'ON_BOARD'));
    expect(onBoard.line, t('widget.onBus'));
    expect(onBoard.live, isFalse);

    final at = DateTime(2026, 9, 25, 14, 32);
    final home = busWidgetLine(_bus(visible: false, reason: 'already_alighted', alightedAt: at));
    expect(home.line, tv('widget.droppedAt', {'time': hhmm(at)}));
    expect(home.live, isFalse);
  });

  test('a stale position never shows a countdown', () {
    final line = busWidgetLine(_bus(eta: 3, stale: true));
    expect(line.live, isFalse);
    expect(line.line, isNot(tn('widget.arrivesIn', 3)));
  });

  test('no bus today says the plain reason', () {
    final line = busWidgetLine(_bus(visible: false, reason: 'no_trip_today'));
    expect(line.line, t('reason.noTripToday'));
    expect(line.live, isFalse);
  });

  test('the words are there in Kurdish and Arabic too', () {
    const keys = ['widget.title', 'widget.arrivesIn', 'widget.onBus', 'widget.notLive', 'widget.signIn', 'widget.off'];
    final english = {for (final k in keys) k: t(k)};
    for (final lang in [Lang.ckb, Lang.ar]) {
      AppLocale.current.value = lang;
      for (final key in keys) {
        expect(t(key), isNot(key));
        expect(t(key), isNot(english[key]));
      }
      expect(tn('widget.arrivesIn', 5), contains('5'));
    }
  });
}
