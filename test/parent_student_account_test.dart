import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/parent/student_account_screen.dart';

const _lana = 'ckstudentlana00000000001';
const _zeyn = 'ckstudentzeyn00000000001';

typedef _Call = ({String method, String path, Object? body});

Map<String, Object?> _child(
  String id,
  String name, {
  int? gradeLevel = 7,
  bool oldEnough = true,
  bool blockedByOffice = false,
  bool enabled = false,
  bool passwordSet = false,
  bool mayBeSwitchedOn = true,
}) =>
    {
      'studentId': id,
      'code': 'S-$name',
      'name': name,
      'names': {'en': name, 'ar': 'ع $name', 'ckb': 'ک $name'},
      'gradeLevel': gradeLevel,
      'oldEnough': oldEnough,
      'blockedByOffice': blockedByOffice,
      'enabled': enabled,
      'passwordSet': passwordSet,
      'lastLoginAt': null,
      'mayBeSwitchedOn': mayBeSwitchedOn,
      'canOpenTheApp': mayBeSwitchedOn && enabled && passwordSet,
    };

class _Server {
  _Server({required this.body});

  Map<String, Object?> body;
  final List<_Call> calls = [];

  http.Client client() => MockClient((request) async {
        final sent = request.body.isEmpty ? null : jsonDecode(request.body);
        calls.add((method: request.method, path: request.url.path, body: sent));
        if (request.method == 'POST') {
          final children = (body['children'] as List).cast<Map<String, Object?>>();
          final id = request.url.pathSegments[request.url.pathSegments.length - 2];
          final child = children.firstWhere((c) => c['studentId'] == id);
          if (request.url.path.endsWith('/switch')) {
            child['enabled'] = (sent as Map)['enabled'];
          } else {
            child['passwordSet'] = true;
          }
          child['canOpenTheApp'] = child['enabled'] == true && child['passwordSet'] == true;
          return _json(200, child);
        }
        return _json(200, body);
      });

  static http.Response _json(int status, Object? json) => http.Response.bytes(
        utf8.encode(jsonEncode(json)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  List<_Call> posts() => [for (final c in calls) if (c.method == 'POST') c];
}

Future<void> _open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: StudentAccountScreen()));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.current.value = Lang.en;
  });

  testWidgets('a parent turns the account on and the school minimum is named', (tester) async {
    final server = _Server(body: {
      'schoolOpen': true,
      'minGradeLevel': 5,
      'children': [_child(_lana, 'Lana')],
    });
    ApiClient.instance.httpForTest = server.client();

    await _open(tester);

    expect(find.text(tn('studentAccount.fromGrade', 5)), findsOneWidget);
    expect(find.text(t('studentAccount.letThemIn')), findsOneWidget);
    expect(find.text(t('studentAccount.setPassword')), findsOneWidget);
    expect(find.text(t('studentAccount.noPasswordYet')), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(server.posts(), hasLength(1));
    expect(server.posts().single.path, '/parent/student-accounts/$_lana/switch');
    expect(server.posts().single.body, {'enabled': true});
    expect(find.text(t('studentAccount.needsPassword')), findsOneWidget);
  });

  testWidgets('a school that has not opened the student app offers no switch', (tester) async {
    ApiClient.instance.httpForTest = _Server(body: {
      'schoolOpen': false,
      'minGradeLevel': 5,
      'children': [_child(_lana, 'Lana', mayBeSwitchedOn: false)],
    }).client();

    await _open(tester);

    expect(find.text(t('studentAccount.schoolClosedBody')), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.text(t('studentAccount.setPassword')), findsNothing);
  });

  testWidgets('a child the office switched off is not offered back on by the parent',
      (tester) async {
    ApiClient.instance.httpForTest = _Server(body: {
      'schoolOpen': true,
      'minGradeLevel': 5,
      'children': [
        _child(_lana, 'Lana', blockedByOffice: true, mayBeSwitchedOn: false, enabled: true),
      ],
    }).client();

    await _open(tester);

    expect(find.text(t('studentAccount.officeClosedIt')), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('a child in too young a class is told why, not offered the switch', (tester) async {
    ApiClient.instance.httpForTest = _Server(body: {
      'schoolOpen': true,
      'minGradeLevel': 5,
      'children': [
        _child(_zeyn, 'Zeyn', gradeLevel: 2, oldEnough: false, mayBeSwitchedOn: false),
      ],
    }).client();

    await _open(tester);

    expect(find.text(t('studentAccount.tooYoung')), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('the password must be long enough, carry a number and be typed twice',
      (tester) async {
    final server = _Server(body: {
      'schoolOpen': true,
      'minGradeLevel': 5,
      'children': [_child(_lana, 'Lana', enabled: true)],
    });
    ApiClient.instance.httpForTest = server.client();

    await _open(tester);
    await tester.tap(find.text(t('studentAccount.setPassword')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'short1');
    await tester.tap(find.text(t('common.save')));
    await tester.pumpAndSettle();
    expect(find.text(t('login.tooShort')), findsOneWidget);
    expect(server.posts(), isEmpty);

    await tester.enterText(fields.first, 'onlyletters');
    await tester.tap(find.text(t('common.save')));
    await tester.pumpAndSettle();
    expect(find.text(t('login.rule')), findsWidgets);
    expect(server.posts(), isEmpty);

    await tester.enterText(fields.first, 'Sunflower7');
    await tester.enterText(fields.last, 'Sunflower8');
    await tester.tap(find.text(t('common.save')));
    await tester.pumpAndSettle();
    expect(find.text(t('login.mismatch')), findsOneWidget);
    expect(server.posts(), isEmpty);

    await tester.enterText(fields.last, 'Sunflower7');
    await tester.tap(find.text(t('common.save')));
    await tester.pumpAndSettle();

    expect(server.posts(), hasLength(1));
    expect(server.posts().single.path, '/parent/student-accounts/$_lana/password');
    expect(server.posts().single.body, {'password': 'Sunflower7'});
    expect(find.text(t('studentAccount.ready')), findsOneWidget);
  });

  testWidgets('a refusal from the server is shown, and nothing is claimed to have changed',
      (tester) async {
    ApiClient.instance.httpForTest = MockClient((request) async {
      if (request.method == 'POST') {
        return _Server._json(403, {'message': 'The school office has switched this off.'});
      }
      return _Server._json(200, {
        'schoolOpen': true,
        'minGradeLevel': 5,
        'children': [_child(_lana, 'Lana')],
      });
    });

    await _open(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('The school office has switched this off.'), findsOneWidget);
    expect(find.text(t('studentAccount.off')), findsOneWidget);
  });
}
