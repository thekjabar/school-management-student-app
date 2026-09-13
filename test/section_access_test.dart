import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/parent_api.dart';

PackageEntitlements _catalogue({required List<Map<String, Object?>> children}) =>
    PackageEntitlements.fromJson({
      'sections': [
        {'key': 'parent.marks', 'paid': true, 'name': {'en': 'Marks', 'ckb': 'نمرەکان'}},
        {'key': 'parent.timetable', 'paid': false},
      ],
      'children': children,
    });

void main() {
  test('nothing is decided before the catalogue has loaded', () {
    expect(PackageEntitlements.none.access('kid', ParentSection.marks), SectionAccess.unknown);
    expect(PackageEntitlements.none.isLocked('kid', ParentSection.marks), isFalse);
  });

  test('a paid section is locked for a child without the package and open for one with it', () {
    final ent = _catalogue(children: [
      {'studentId': 'without', 'lockedSections': ['parent.marks']},
      {'studentId': 'with', 'lockedSections': <String>[]},
    ]);
    expect(ent.access('without', ParentSection.marks), SectionAccess.locked);
    expect(ent.access('with', ParentSection.marks), SectionAccess.open);
  });

  test('a free section and a key the catalogue does not list are open for everyone', () {
    final ent = _catalogue(children: [
      {'studentId': 'without', 'lockedSections': ['parent.marks']},
    ]);
    expect(ent.access('without', ParentSection.timetable), SectionAccess.open);
    expect(ent.access('without', ParentSection.routeSafety), SectionAccess.open);
  });

  test('a child the server did not describe is locked out of paid sections', () {
    final ent = _catalogue(children: const []);
    expect(ent.access('stranger', ParentSection.marks), SectionAccess.locked);
  });

  test('a household section stays open while any child still has it', () {
    final ent = _catalogue(children: [
      {'studentId': 'a', 'lockedSections': ['parent.marks']},
      {'studentId': 'b', 'lockedSections': <String>[]},
    ]);
    expect(ent.lockedForAll(['a', 'b'], ParentSection.marks), isFalse);
    expect(ent.lockedForAll(['a'], ParentSection.marks), isTrue);
  });

  test('children from a second school merge in without dropping the first', () {
    final first = _catalogue(children: [
      {'studentId': 'a', 'lockedSections': <String>[]},
    ]);
    final second = _catalogue(children: [
      {'studentId': 'b', 'lockedSections': ['parent.marks']},
    ]);
    final merged = first.withChildrenFrom(second);
    expect(merged.access('a', ParentSection.marks), SectionAccess.open);
    expect(merged.access('b', ParentSection.marks), SectionAccess.locked);
  });

  test('the lock signature changes when a package lapses', () {
    final paying = _catalogue(children: [
      {'studentId': 'a', 'lockedSections': <String>[]},
    ]);
    final lapsed = _catalogue(children: [
      {'studentId': 'a', 'lockedSections': ['parent.marks']},
    ]);
    expect(paying.lockSignature('a'), isNot(lapsed.lockSignature('a')));
  });

  test('section names come from the catalogue in the reader\'s language', () {
    final ent = _catalogue(children: const []);
    expect(ent.nameFor(ParentSection.marks, 'ckb'), 'نمرەکان');
    expect(ent.nameFor(ParentSection.marks, 'ar'), 'Marks');
    expect(ent.nameFor(ParentSection.timetable, 'en'), isNull);
  });
}
