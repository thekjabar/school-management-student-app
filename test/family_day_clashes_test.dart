import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/family_day.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/parent/family_day_screen.dart';

FamilyChildDay _child(String name, {String? pickupAt, String? pickupPlace, String? dropAt, String? dropPlace}) => FamilyChildDay(
      studentId: 'cmstudent$name',
      name: '$name Omar',
      school: 'School of $name',
      closed: false,
      noBus: false,
      note: null,
      pickup: pickupAt == null ? null : FamilyMoment(at: DateTime.parse(pickupAt), place: pickupPlace),
      dropoff: dropAt == null ? null : FamilyMoment(at: DateTime.parse(dropAt), place: dropPlace),
    );

void main() {
  setUp(() => AppLocale.current.value = Lang.en);

  test('two pickups ten minutes apart at different places clash', () {
    final clashes = familyClashes([
      _child('Lana', pickupAt: '2026-09-27T07:10:00', pickupPlace: 'Ankawa gate'),
      _child('Ari', pickupAt: '2026-09-27T07:20:00', pickupPlace: 'Iskan street'),
    ]);
    expect(clashes, hasLength(1));
    expect(clashes.single.kind, ClashKind.pickup);
    expect(clashes.single.minutesApart, 10);
    expect(clashSentence(clashes.single), tv('familyDay.clashPickup', {'a': 'Lana', 'b': 'Ari', 'n': 10}));
  });

  test('the same place, or times far apart, is no clash', () {
    expect(
      familyClashes([
        _child('Lana', pickupAt: '2026-09-27T07:10:00', pickupPlace: 'Ankawa gate'),
        _child('Ari', pickupAt: '2026-09-27T07:15:00', pickupPlace: 'ankawa gate '),
      ]),
      isEmpty,
    );
    expect(
      familyClashes([
        _child('Lana', pickupAt: '2026-09-27T07:00:00', pickupPlace: 'Ankawa gate'),
        _child('Ari', pickupAt: '2026-09-27T07:40:00', pickupPlace: 'Iskan street'),
      ]),
      isEmpty,
    );
  });

  test('drop-offs are checked too, and a child with no bus is never a clash', () {
    final clashes = familyClashes([
      _child('Lana', dropAt: '2026-09-27T13:00:00', dropPlace: 'Home street'),
      _child('Ari', dropAt: '2026-09-27T13:05:00', dropPlace: 'Grandma house'),
      _child('Sara'),
    ]);
    expect(clashes.map((c) => c.kind), [ClashKind.dropoff]);
  });

  test('the warning and the advice read in Kurdish and Arabic', () {
    for (final lang in [Lang.ckb, Lang.ar]) {
      AppLocale.current.value = lang;
      expect(t('familyDay.fix'), isNot('familyDay.fix'));
      expect(tv('familyDay.clashPickup', {'a': 'Lana', 'b': 'Ari', 'n': 10}), allOf(contains('Lana'), contains('Ari'), contains('10')));
    }
  });
}
