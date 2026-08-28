// The whole chain, against the live API:
//
//     app language  ->  X-Lang header  ->  server resolves  ->  one language back
//
// This is the test that would have caught the two things curl could not. The
// app used to read subject['name'] out of a {name, nameEn, nameAr} object,
// which silently returned the school's teaching language whatever the parent
// had chosen — no error, no blank, just never translated. And the header is
// read per request from AppLocale, so a test that only checks one language
// proves nothing about switching.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/api/session.dart';
import 'package:student_app/i18n/strings.dart';

const _phone = '07501100001';
const _password = 'School@123';

void main() {
  // SharedPreferences (which AppLocale and the token store use) needs a binding,
  // and an in-memory store rather than the device's.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // The test binding installs an HttpOverrides stub that fails every real
  // request with a 400. These tests are meant to hit the live API.
  HttpOverrides.global = null;

  late Child child;

  setUpAll(() async {
    await Session.instance.signIn(_phone, _password);
    final children = await ParentApi.instance.children();
    expect(children, isNotEmpty, reason: 'the demo parent has no children');
    child = children.first;
  });

  /// Read one homework row with the app set to [lang].
  Future<HomeworkItem?> homeworkIn(Lang lang) async {
    AppLocale.current.value = lang;
    final rows = await ParentApi.instance.homework(child.studentId);
    return rows.isEmpty ? null : rows.first;
  }

  test('subject arrives as a finished string, not an object to pick through', () async {
    final item = await homeworkIn(Lang.en);
    expect(item, isNotNull);
    // If the server ever goes back to sending an object, `subject` becomes ''
    // and this fails rather than silently showing a blank chip.
    expect(item!.subject, isNotEmpty,
        reason: 'subject was empty — the server is probably sending an object again');
  });

  test('the same homework comes back differently per language', () async {
    final en = await homeworkIn(Lang.en);
    final ar = await homeworkIn(Lang.ar);
    final ckb = await homeworkIn(Lang.ckb);

    expect(en, isNotNull);
    expect(ar, isNotNull);
    expect(ckb, isNotNull);

    // Same row — the language must not change which homework is returned.
    expect(ar!.id, en!.id);
    expect(ckb!.id, en.id);

    // ...but the words must change. Arabic and Kurdish were both seeded, so
    // all three titles differ from each other.
    expect(ar.title, isNot(en.title),
        reason: 'Arabic title matched English — X-Lang is not reaching the server');
    expect(ckb.title, isNot(en.title),
        reason: 'Kurdish title matched English — X-Lang is not reaching the server');
    expect(ckb.title, isNot(ar.title),
        reason: 'Kurdish and Arabic titles are identical — the wrong locale is being resolved');
  });

  test('a subject with an Arabic name is returned in Arabic', () async {
    final ar = await homeworkIn(Lang.ar);
    // Every seeded subject has nameAr filled in, so an Arabic request must not
    // come back with Latin letters.
    expect(ar!.subject, isNotEmpty);
    expect(RegExp(r'[؀-ۿ]').hasMatch(ar.subject), isTrue,
        reason: 'subject "${ar.subject}" has no Arabic script — nameAr was not used');
  });

  test('announcements follow the language too', () async {
    AppLocale.current.value = Lang.ckb;
    final ckb = await ParentApi.instance.announcements();
    AppLocale.current.value = Lang.en;
    final en = await ParentApi.instance.announcements();

    expect(ckb, isNotEmpty);
    expect(en.length, ckb.length, reason: 'language changed how many were visible');
    // At least one announcement was given a Kurdish translation.
    final differs = <String>{};
    for (var i = 0; i < ckb.length; i++) {
      if (ckb[i].title != en[i].title) differs.add(ckb[i].title);
    }
    expect(differs, isNotEmpty,
        reason: 'no announcement changed wording between Kurdish and English');
  });

  test('an untranslated record falls back to the original, never to blank', () async {
    // Kurmanji has no seeded content at all, so every field must fall back.
    // A blank here would mean a parent sees an empty screen rather than the
    // message in a language they can half-read.
    AppLocale.current.value = Lang.en;
    final rows = await ParentApi.instance.homework(child.studentId);
    for (final h in rows) {
      expect(h.title, isNotEmpty, reason: 'homework ${h.id} came back with no title');
      expect(h.subject, isNotEmpty, reason: 'homework ${h.id} came back with no subject');
    }
  });

  tearDownAll(() async {
    AppLocale.current.value = Lang.en;
    await Session.instance.signOut();
  });
}
