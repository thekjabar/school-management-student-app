import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/api/names_input.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/api/session.dart';
import 'package:student_app/i18n/strings.dart';

Map<String, Object?> _me({Object? names}) => {
      'person': {
        'id': 'ckguardian00000000000001',
        'name': 'ئاری ئەحمەد',
        'names': names,
        'phoneE164': '+9647501100001',
        'phoneVerified': true,
      },
      'active': {'tenantId': 'cktenant0000000000000001', 'role': 'GUARDIAN'},
      'memberships': [
        {'tenantId': 'cktenant0000000000000001', 'tenantName': 'Demo', 'role': 'GUARDIAN'},
      ],
    };

http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.current.value = Lang.en;
  });

  tearDown(() => AppLocale.current.value = Lang.en);

  group('the account name', () {
    test('follows the app language from the names the API sent', () {
      final me = Me.fromJson(_me(names: {'ckb': 'ئاری ئەحمەد', 'ar': 'آري أحمد', 'en': 'Ari Ahmed'}));
      expect(me.name, 'Ari Ahmed');
      expect(me.firstName, 'Ari');
      AppLocale.current.value = Lang.ar;
      expect(me.name, 'آري أحمد');
      AppLocale.current.value = Lang.ckb;
      expect(me.name, 'ئاری ئەحمەد');
    });

    test('falls back to the name as sent when a language is missing or names are absent', () {
      expect(Me.fromJson(_me(names: {'ckb': 'ئاری ئەحمەد', 'ar': null, 'en': ''})).name, 'ئاری ئەحمەد');
      expect(Me.fromJson(_me()).name, 'ئاری ئەحمەد');
    });
  });

  group('correction requests', () {
    test('read every name part in every language from the changes the API returns', () {
      final change = ProfileChange.fromJson({
        'id': 'ckrequest000000000000001',
        'status': 'PENDING',
        'requestedAt': '2026-09-15T08:00:00.000Z',
        'proposedNameGiven': 'ئاری',
        'changes': [
          {'field': 'nameGiven', 'currentValue': 'ئاریی', 'proposedValue': 'ئاری'},
          {'field': 'nameGivenAr', 'currentValue': null, 'proposedValue': 'آري'},
          {'field': 'nameFamilyEn', 'currentValue': 'Ahmad', 'proposedValue': 'Ahmed'},
          {'field': 'nameFatherEn', 'currentValue': 'Hawre', 'proposedValue': null},
          {'field': 'somethingElse', 'proposedValue': 'x'},
        ],
      });
      expect(change.fields.map((f) => f.field), ['nameGiven', 'nameGivenAr', 'nameFamilyEn', 'nameFatherEn']);
      expect(change.fields.map((f) => f.value), ['ئاری', 'آري', 'Ahmed', '']);
    });

    test('read the proposed columns when a response carries no changes list', () {
      final change = ProfileChange.fromJson({
        'id': 'ckrequest000000000000002',
        'status': 'APPROVED',
        'requestedAt': '2026-09-15T08:00:00.000Z',
        'proposedNameGivenEn': 'Ari',
        'proposedEmail': 'ari@example.com',
      });
      expect(change.fields, [(field: 'nameGivenEn', value: 'Ari'), (field: 'email', value: 'ari@example.com')]);
    });

    test('refuse an Arabic part in other letters and an English part in Arabic letters', () {
      expect(profileNameScriptError({'nameGivenAr': 'آري', 'nameGivenEn': "O'Neil-Ahmed"}), isNull);
      expect(profileNameScriptError({'nameGivenAr': 'Ari'}), 'personal.arabicLettersOnly');
      expect(profileNameScriptError({'nameFamilyEn': 'أحمد'}), 'personal.englishLettersOnly');
      expect(profileNameScriptError({'nameFamilyEn': '  '}), isNull);
    });

    test('send the Arabic and English parts beside the Kurdish ones', () async {
      Object? sent;
      ApiClient.instance.httpForTest = MockClient((request) async {
        if (request.url.path.endsWith('/auth/profile/change-requests')) {
          sent = jsonDecode(request.body);
          return _json(201, {'id': 'x'});
        }
        return _json(404, {'message': 'not here'});
      });
      await ParentApi.instance.askProfileChange(
        nameGiven: 'ئاری',
        otherLanguages: {'nameGivenAr': 'آري', 'nameFamilyEn': 'Ahmed', 'role': 'ADMIN'},
      );
      expect(sent, {'nameGiven': 'ئاری', 'nameGivenAr': 'آري', 'nameFamilyEn': 'Ahmed'});
    });
  });

  group('home address', () {
    test('the home reads every stored language of the address and directions', () {
      final home = HomeLocation.fromJson({
        'address': 'Gulan Street',
        'addresses': {'ckb': 'شەقامی گوڵان', 'ar': 'شارع كولان', 'en': 'Gulan Street'},
        'note': null,
        'notes': {'ckb': 'دەرگای شین', 'ar': null, 'en': null},
        'lat': 36.19,
        'lon': 44.01,
        'children': [],
      });
      expect(home.addresses.ar, 'شارع كولان');
      expect(home.notes.ckb, 'دەرگای شین');
      expect(home.notes.en, isNull);
    });

    const geocoded = LocalText(ckb: 'شەقامی گوڵان، هەولێر', ar: 'شارع كولان، أربيل', en: 'Gulan Street, Erbil');

    test('a moved pin sends the address in Kurdish, Arabic and English', () {
      final body = homeAddressBody(
        reading: Lang.en,
        lat: 36.19,
        lon: 44.01,
        address: 'Gulan Street',
        addressShown: 'Gulan Street',
        note: '',
        noteShown: '',
        stored: const LocalText(ckb: 'کۆن'),
        geocoded: geocoded,
        pinMoved: true,
      );
      expect(body, {
        'lat': 36.19,
        'lon': 44.01,
        'address': 'شەقامی گوڵان، هەولێر',
        'addressAr': 'شارع كولان، أربيل',
        'addressEn': 'Gulan Street, Erbil',
      });
    });

    test('an unmoved pin fills only the languages the family has no address in', () {
      final body = homeAddressBody(
        reading: Lang.ckb,
        lat: 36.19,
        lon: 44.01,
        address: 'کۆن',
        addressShown: 'کۆن',
        note: '',
        noteShown: '',
        stored: const LocalText(ckb: 'کۆن', en: 'Old'),
        geocoded: geocoded,
      );
      expect(body, {'lat': 36.19, 'lon': 44.01, 'addressAr': 'شارع كولان، أربيل'});
    });

    test('typed text goes into the language it is written in and wins over the lookup', () {
      final english = homeAddressBody(
        reading: Lang.ar,
        address: 'House 12, Gulan Street',
        addressShown: 'شارع كولان',
        note: 'Blue gate',
        noteShown: '',
        geocoded: geocoded,
        pinMoved: true,
      );
      expect(english['addressEn'], 'House 12, Gulan Street');
      expect(english['addressAr'], 'شارع كولان، أربيل');
      expect(english['noteEn'], 'Blue gate');
      expect(english.containsKey('note'), isFalse);

      final arabic = homeAddressBody(
        reading: Lang.ar,
        address: 'بيت ١٢ شارع كولان',
        addressShown: '',
        note: 'دەرگای شین',
        noteShown: '',
      );
      expect(arabic, {'addressAr': 'بيت ١٢ شارع كولان', 'noteAr': 'دەرگای شین'});

      final kurdishForEnglishReader = homeAddressBody(
        reading: Lang.en,
        address: 'ماڵی ١٢',
        addressShown: '',
        note: '',
        noteShown: 'Blue gate',
      );
      expect(kurdishForEnglishReader, {'address': 'ماڵی ١٢', 'noteEn': ''});
    });

    test('a lookup in the wrong letters is never sent into that language', () {
      final body = homeAddressBody(
        reading: Lang.en,
        address: '',
        addressShown: '',
        note: '',
        noteShown: '',
        geocoded: const LocalText(ckb: 'Gulan', ar: 'Gulan Street', en: 'شارع كولان'),
        pinMoved: true,
      );
      expect(body, isEmpty);
    });
  });

  group('address lookup', () {
    test('asks OpenStreetMap once per language with the KSP user agent, a second apart, and caches', () async {
      final requests = <http.Request>[];
      final pauses = <Duration>[];
      var now = DateTime(2026, 9, 15, 8);
      final answers = {
        'ckb': 'شەقامی گوڵان, گەڕەکی ئازادی, هەولێر, 44001, Iraq',
        'ar': 'شارع كولان, حي آزادي, أربيل, 44001, العراق',
        'en': 'Gulan Street, شارع, Erbil, 44001, Iraq',
      };
      final geocoder = AddressGeocoder(
        client: MockClient((request) async {
          requests.add(request);
          now = now.add(const Duration(milliseconds: 200));
          return _json(200, {'display_name': answers[request.url.queryParameters['accept-language']]});
        }),
        clock: () => now,
        pause: (gap) async {
          pauses.add(gap);
          now = now.add(gap);
        },
      );

      final found = await geocoder.at(36.19, 44.01);
      expect(found.ckb, 'شەقامی گوڵان، گەڕەکی ئازادی، هەولێر');
      expect(found.ar, 'شارع كولان، حي آزادي، أربيل');
      expect(found.en, 'Gulan Street, Erbil, Iraq');

      expect(requests.map((r) => r.url.queryParameters['accept-language']), ['ckb', 'ar', 'en']);
      for (final r in requests) {
        expect(r.url.host, 'nominatim.openstreetmap.org');
        expect(r.url.path, '/reverse');
        expect(r.headers['User-Agent'], 'KSP/1.0 (com.kurdistanstudentprotection.ksp)');
      }
      expect(pauses, [const Duration(milliseconds: 800), const Duration(milliseconds: 800)]);

      final again = await geocoder.at(36.19, 44.01);
      expect(again.en, found.en);
      expect(requests, hasLength(3));
    });

    test('a failed lookup gives nothing and is asked again next time', () async {
      var calls = 0;
      final geocoder = AddressGeocoder(
        client: MockClient((request) async {
          calls++;
          return http.Response('busy', 503);
        }),
        pause: (_) async {},
      );
      final found = await geocoder.at(36.19, 44.01);
      expect([found.ckb, found.ar, found.en], [null, null, null]);
      await geocoder.at(36.19, 44.01);
      expect(calls, 6);
    });
  });
}
