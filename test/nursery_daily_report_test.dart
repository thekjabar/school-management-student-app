import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/i18n/strings.dart';

const _moods = ['HAPPY', 'CALM', 'PLAYFUL', 'TIRED', 'UPSET', 'UNWELL'];
const _meals = ['BREAKFAST', 'SNACK', 'LUNCH'];
const _amounts = ['ALL', 'SOME', 'NONE'];
const _toilet = ['NAPPY_DRY', 'NAPPY_WET', 'NAPPY_SOILED', 'TOILET_WEE', 'TOILET_POO', 'ACCIDENT'];

void main() {
  const nursery = 'cmstudent000000000000001';
  const schoolChild = 'cmstudent000000000000002';

  final ent = PackageEntitlements.fromJson({
    'sections': [
      {'key': 'parent.dailyReport', 'paid': false, 'stage': 'KINDERGARTEN', 'name': {'en': 'Daily report'}, 'blurb': {}},
      {'key': 'parent.marks', 'paid': false, 'stage': 'SCHOOL', 'name': {'en': 'Marks'}, 'blurb': {}},
    ],
    'children': [
      {
        'studentId': nursery,
        'stage': 'KINDERGARTEN',
        'lockedSections': [],
        'sections': ['parent.dailyReport'],
      },
      {
        'studentId': schoolChild,
        'stage': 'SCHOOL',
        'lockedSections': [],
        'sections': ['parent.marks'],
      },
    ],
  });

  test('the daily report belongs to a nursery child', () {
    expect(ent.applies(nursery, 'parent.dailyReport'), isTrue);
    expect(ent.access(nursery, 'parent.dailyReport'), SectionAccess.open);
  });

  test('a school child never sees the daily report', () {
    expect(ent.applies(schoolChild, 'parent.dailyReport'), isFalse);
    expect(ent.access(schoolChild, 'parent.dailyReport'), SectionAccess.hidden);
  });

  test('a day comes back whole', () {
    final day = DailyReport.fromJson({
      'id': 'cmday000000000000000001a',
      'day': '2026-09-21',
      'sentAt': '2026-09-21T13:00:00.000Z',
      'className': 'باخچە ٢ — A',
      'classNames': {'ckb': 'باخچە ٢ — A'},
      'mood': 'HAPPY',
      'activities': 'Painting and singing.',
      'bringTomorrow': ['nappies', '  ', 'spare clothes'],
      'carerNote': 'A calm day.',
      'meals': [
        {'id': 'm1', 'meal': 'BREAKFAST', 'amount': 'ALL', 'note': null},
        {'id': 'm2', 'meal': 'LUNCH', 'amount': 'SOME', 'note': 'left the rice'},
      ],
      'naps': [
        {'id': 'n1', 'startedAt': '2026-09-21T10:00:00.000Z', 'endedAt': '2026-09-21T11:00:00.000Z', 'minutes': 60},
        {'id': 'n2', 'startedAt': '2026-09-21T12:30:00.000Z', 'endedAt': null, 'minutes': null},
      ],
      'toilet': [
        {'id': 't1', 'at': '2026-09-21T09:30:00.000Z', 'kind': 'NAPPY_WET', 'note': null},
      ],
      'photos': [
        {'id': 'p1', 'caption': 'At the sand table', 'url': 'https://example/p1.jpg', 'width': 800, 'height': 600},
      ],
    });

    expect(day.mood, 'HAPPY');
    expect(day.meals.length, 2);
    expect(day.meals[1].note, 'left the rice');
    expect(day.naps.length, 2);
    expect(day.sleepMinutes, 60);
    expect(day.toilet.single.kind, 'NAPPY_WET');
    expect(day.photos.single.thumbnailUrl, 'https://example/p1.jpg');
    expect(day.bringTomorrow, ['nappies', 'spare clothes']);
  });

  test('a day with nothing logged yet does not crash', () {
    final empty = DailyReport.fromJson({'id': 'x', 'day': '2026-09-21'});
    expect(empty.meals, isEmpty);
    expect(empty.naps, isEmpty);
    expect(empty.sleepMinutes, 0);
    expect(empty.bringTomorrow, isEmpty);
    expect(empty.mood, isNull);
  });

  test('every mood, meal, amount and nappy kind is named in all three languages', () {
    final keys = <String>[
      for (final m in _moods) 'dailyReport.mood.$m',
      for (final m in _meals) 'dailyReport.meal.$m',
      for (final a in _amounts) 'dailyReport.amount.$a',
      for (final k in _toilet) 'dailyReport.toiletKind.$k',
    ];

    final missing = <String, List<String>>{};
    for (final lang in Lang.values) {
      final gaps = keys.where((k) => !tableFor(lang).containsKey(k)).toList();
      if (gaps.isNotEmpty) missing[lang.code] = gaps;
    }
    expect(missing, isEmpty, reason: 'unnamed in some language: $missing');
  });

  test('no language quietly reuses the English word for a mood', () {
    AppLocale.current.value = Lang.ckb;
    for (final mood in _moods) {
      final ckb = tableFor(Lang.ckb)['dailyReport.mood.$mood'];
      expect(ckb, isNotNull);
      expect(ckb, isNot(equals(tableFor(Lang.en)['dailyReport.mood.$mood'])));
    }
    AppLocale.current.value = Lang.en;
  });
}
