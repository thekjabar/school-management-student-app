// Does the register the teacher app fetches really carry a photograph field,
// and does the client turn it into an address a phone can load?
//
// The photo grid is only as honest as this parse. A field name that is one
// letter out parses to null for every child, the grid draws thirty "no
// photograph" panels, and nothing anywhere says it is broken — so this asks the
// live platform rather than a fixture, and prints what came back.
//
//   flutter test test/register_photo_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/api/session.dart';
import 'package:student_app/api/teacher_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/teacher/classes_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  // Fetched here rather than inside the widget test: a testWidgets body runs in
  // fake async, where a real network future never completes.
  late TeachingSlot slot;

  setUpAll(() async {
    final r = await Session.instance.signIn('07511100001', 'School@123');
    expect(r.me.role, 'TEACHER');
    final classes = await TeacherApi.instance.classes();
    expect(classes, isNotEmpty, reason: 'this teacher takes no classes');
    slot = classes.first;
  });

  test('the register carries a photograph field the client can parse', () async {
    final sheet = await TeacherApi.instance.register(slot.classId);
    expect(sheet.marks, isNotEmpty, reason: 'nobody on the register');

    // The raw payload, so a renamed server field fails HERE rather than as a
    // grid of empty panels on a teacher's phone.
    final raw = await ApiClient.instance
        .get('/teacher/classes/${slot.classId}/attendance') as Map<String, dynamic>;
    final rows = (raw['students'] as List).cast<Map<String, dynamic>>();
    expect(
      rows.first.containsKey('photoUrl'),
      isTrue,
      reason: 'the register no longer serves photoUrl: ${rows.first.keys.join(', ')}',
    );

    // Whatever the server holds a photograph for, the model must hold one for
    // too. A parse that silently drops them all is the failure this grid would
    // hide best: every tile would look like a family that never consented.
    final rawPhotos = rows
        .where((r) => (r['photoUrl'] as String?)?.trim().isNotEmpty ?? false)
        .length;

    var withPhoto = 0;
    for (final m in sheet.marks) {
      final url = m.photoUrl;
      if (url == null) continue;
      withPhoto++;
      // Null or absolute — never a bare path, which would silently fail to
      // load and look exactly like a child with no photograph on file.
      expect(url.startsWith('http'), isTrue, reason: 'not an address: $url');
    }
    expect(withPhoto, rawPhotos, reason: 'the parse lost a photograph');
    // ignore: avoid_print
    print('  ${sheet.marks.length} on the register, $withPhoto with a photograph '
        '($rawPhotos in the payload)');
  }, timeout: const Timeout(Duration(minutes: 2)));

  // The grid, on the real screen, against the real register.
  //
  // Layout is the risk a compile does not catch: thirty tiles three across on a
  // handset, each with a name that may run to two lines in Kurdish. An overflow
  // here would be a red-striped register.
  testWidgets('the faces mode marks the same register the list does', (tester) async {
    AppLocale.current.value = Lang.en;

    // runAsync, because the register really is fetched over the network here,
    // and pumpAndSettle would never settle on the loader's spinner anyway.
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: RegisterScreen(slot: slot)));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (find.byIcon(Icons.grid_view_rounded).evaluate().isNotEmpty &&
            find.textContaining('#').evaluate().isNotEmpty) {
          break;
        }
      }
    });
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    // Every child on this register is a child the school holds no consented
    // photograph for, and every one of them says so rather than showing a
    // circle of initials that would look like a face somebody checked.
    final noPhoto = find.text(t('teacher.noPhotoShort'));
    expect(noPhoto, findsWidgets);
    final tiles = noPhoto.evaluate().length;

    // The tile, not the label inside it: the whole face is the target a
    // teacher's thumb lands on.
    final face = find
        .ancestor(of: noPhoto.first, matching: find.byType(InkWell))
        .first;

    final absentBefore = find.text(t('att.absent')).evaluate().length;
    await tester.tap(face);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(t('att.absent')).evaluate().length,
      absentBefore + 1,
      reason: 'tapping a face did not mark the child absent',
    );

    // And back: the same tap is the way out of a slip.
    await tester.tap(face);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(t('att.absent')).evaluate().length, absentBefore);

    // Late and excused are behind a press-and-hold, and they write through the
    // same marks: no register anywhere in this app is edited twice.
    final lateBefore = find.text(t('att.late')).evaluate().length;
    await tester.longPress(face);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    final lateButton = find.text(t('teacher.markLate'));
    expect(lateButton, findsOneWidget, reason: 'no late button in the sheet');
    await tester.tap(lateButton);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(
      find.text(t('att.late')).evaluate().length,
      lateBefore + 1,
      reason: 'the held face was not marked late',
    );

    // ignore: avoid_print
    print('  $tiles faces drawn, none of them a stand-in for a face');
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
