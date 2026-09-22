import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/awards.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/awards_screen.dart';
import 'package:student_app/theme/app_theme.dart';

Map<String, Object?> _award(
  String id,
  String title, {
  bool revoked = false,
  String? revokedReason,
  String? reason,
  String? className,
  String? issuedOn = '2026-05-04T00:00:00.000Z',
}) =>
    {
      'id': id,
      'title': title,
      'titleNames': {'en': title, 'ckb': 'ک $title', 'ar': 'ع $title'},
      'body': 'Well done',
      'bodyNames': {'en': 'Well done', 'ckb': 'ک باش', 'ar': 'ع أحسنت'},
      'reason': reason,
      'issuedOn': issuedOn,
      'className': className,
      'revoked': revoked,
      'revokedReason': revokedReason,
    };

Future<void> _open(WidgetTester tester, AwardsWall wall, AwardsWords words) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AwardsScreen(
        load: () async => wall,
        words: words,
        tint: AppTheme.amber,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.current.value = Lang.en);
  tearDown(() => AppLocale.current.value = Lang.en);

  test('an award reads in the language the reader chose', () {
    final wall = AwardsWall.fromJson({
      'rows': [_award('c1', 'Top of the class'), _award('c2', 'Kindness', revoked: true)],
      'held': 1,
    });

    expect(wall.rows, hasLength(2));
    expect(wall.held, 1);
    expect(wall.rows.first.title, 'Top of the class');
    expect(wall.rows.first.issuedOn, isNotNull);
    expect(wall.rows[1].revoked, isTrue);

    AppLocale.current.value = Lang.ckb;
    expect(wall.rows.first.title, 'ک Top of the class');
    expect(wall.rows.first.body, 'ک باش');

    AppLocale.current.value = Lang.ar;
    expect(wall.rows.first.title, 'ع Top of the class');
  });

  test('an award with nothing in it still parses', () {
    final wall = AwardsWall.fromJson(const {});
    expect(wall.rows, isEmpty);
    expect(wall.held, 0);

    final bare = Certificate.fromJson(const {});
    expect(bare.title, '');
    expect(bare.issuedOn, isNull);
    expect(bare.revoked, isFalse);
  });

  test('both voices name phrases every language carries', () {
    for (final words in [studentAwardsWords, childAwardsWords]) {
      final keys = [
        words.title,
        words.held,
        words.none,
        words.why,
        words.givenOn,
        words.takenBack,
        words.takenBackWhy,
      ];
      for (final lang in Lang.values) {
        for (final key in keys) {
          expect(
            tableFor(lang).containsKey(key),
            isTrue,
            reason: '$key is missing in ${lang.code}',
          );
        }
      }
    }
  });

  testWidgets('a child with no awards is told so, not shown an empty page', (tester) async {
    await _open(tester, AwardsWall(rows: const [], held: 0), childAwardsWords);
    expect(find.text(t('awards.none')), findsOneWidget);
  });

  testWidgets('a taken-back award says so and gives the reason', (tester) async {
    final wall = AwardsWall.fromJson({
      'rows': [
        _award('c1', 'Top of the class', reason: 'Best marks in the term', className: 'Class 4'),
        _award('c2', 'Kindness', revoked: true, revokedReason: 'Given to the wrong child'),
      ],
      'held': 1,
    });

    await _open(tester, wall, studentAwardsWords);

    expect(find.text(tn('student.awardsHeld', 1)), findsOneWidget);
    expect(find.text('Top of the class'), findsOneWidget);
    expect(find.text('Class 4'), findsOneWidget);
    expect(find.text('Best marks in the term'), findsOneWidget);
    expect(find.text(t('student.awardTakenBack')), findsOneWidget);
    expect(
      find.text(tv('student.awardTakenBackWhy', {'name': 'Given to the wrong child'})),
      findsOneWidget,
    );
  });

  testWidgets('a Kurdish reader gets the Kurdish wording and the Kurdish title', (tester) async {
    AppLocale.current.value = Lang.ckb;
    final wall = AwardsWall.fromJson({
      'rows': [_award('c1', 'Top of the class')],
      'held': 1,
    });

    await _open(tester, wall, childAwardsWords);

    expect(find.text(tableFor(Lang.ckb)['awards.title']!), findsOneWidget);
    expect(find.text('ک Top of the class'), findsOneWidget);
    expect(find.text('Top of the class'), findsNothing);
  });
}
