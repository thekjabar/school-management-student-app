import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/parent_api.dart';

PackageEntitlements _read(Map<String, dynamic> payload) => PackageEntitlements.fromJson(payload);

void main() {
  const nursery = 'cmstudent000000000000001';
  const schoolChild = 'cmstudent000000000000002';

  final ent = _read({
    'sections': [
      {'key': 'parent.attendance', 'paid': false, 'stage': 'BOTH', 'name': {'en': 'Attendance'}, 'blurb': {}},
      {'key': 'parent.memories', 'paid': true, 'stage': 'BOTH', 'name': {'en': 'Photos'}, 'blurb': {}},
      {'key': 'parent.marks', 'paid': true, 'stage': 'SCHOOL', 'name': {'en': 'Marks'}, 'blurb': {}},
      {'key': 'parent.assignments', 'paid': false, 'stage': 'SCHOOL', 'name': {'en': 'Homework'}, 'blurb': {}},
    ],
    'children': [
      {
        'studentId': nursery,
        'stage': 'KINDERGARTEN',
        'lockedSections': ['parent.memories'],
        'sections': ['parent.attendance', 'parent.memories'],
      },
      {
        'studentId': schoolChild,
        'stage': 'SCHOOL',
        'lockedSections': [],
        'sections': ['parent.attendance', 'parent.memories', 'parent.marks', 'parent.assignments'],
      },
    ],
  });

  test('marks and homework are not part of a nursery child’s app', () {
    expect(ent.access(nursery, 'parent.marks'), SectionAccess.hidden);
    expect(ent.access(nursery, 'parent.assignments'), SectionAccess.hidden);
    expect(ent.applies(nursery, 'parent.marks'), isFalse);
  });

  test('the same family’s school child keeps them', () {
    expect(ent.access(schoolChild, 'parent.marks'), SectionAccess.open);
    expect(ent.access(schoolChild, 'parent.assignments'), SectionAccess.open);
  });

  test('what both stages share still obeys the package', () {
    expect(ent.access(nursery, 'parent.attendance'), SectionAccess.open);
    expect(ent.access(nursery, 'parent.memories'), SectionAccess.locked);
    expect(ent.access(schoolChild, 'parent.memories'), SectionAccess.open);
  });

  test('an older server that says nothing about stages loses nothing', () {
    final old = _read({
      'sections': [
        {'key': 'parent.marks', 'paid': true, 'name': {'en': 'Marks'}, 'blurb': {}},
      ],
      'children': [
        {'studentId': schoolChild, 'lockedSections': []},
      ],
    });
    expect(old.applies(schoolChild, 'parent.marks'), isTrue);
    expect(old.access(schoolChild, 'parent.marks'), SectionAccess.open);
  });
}
