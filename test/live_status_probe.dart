import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/status.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/theme/app_theme.dart';
import 'package:student_app/ui/platform_status.dart';

const _role = String.fromEnvironment('PROBE_ROLE', defaultValue: 'parent');

const _expect = String.fromEnvironment('PROBE_EXPECT', defaultValue: 'ok');

const _homeText = 'the app itself';

void main() {
  testWidgets('$_role sees $_expect from the live service', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppLocale.current.value = Lang.en;
    AppTheme.dark = false;
    HttpOverrides.global = null;

    final keyFile = File('tool/status.$_role.key');
    if (!keyFile.existsSync()) {
      fail('tool/status.$_role.key is missing. Copy STATUS_KEY_${_role.toUpperCase()} '
          'from ksp-status-api/.env on the server before rehearsing a window.');
    }
    final key = keyFile.readAsStringSync().trim();

    late final Object? onTheWire;
    await tester.runAsync(() async {
      final raw = await http.get(
        Uri.parse('$kStatusBase/api/status?app=$_role&lang=en'),
        headers: {'X-Status-Key': key},
      );
      expect(raw.statusCode, 200, reason: 'the live service must answer before anything else is believed');
      onTheWire = (jsonDecode(utf8.decode(raw.bodyBytes)) as Map<String, dynamic>)['state'];
      debugPrint('PROBE $_role wire=$onTheWire');
      expect(onTheWire, _expect, reason: 'the service is not in the state this probe was run for');

      PlatformStatusService.instance
        ..resetForTest()
        ..keyForTest = key
        ..httpForTest = http.Client();

      await PlatformStatusService.instance.start(_role);
    });
    final answer = PlatformStatusService.instance.current.value;

    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(body: Center(child: Text(_homeText))),
      builder: (context, child) => StatusGate(
        role: _role == 'driver' ? Role.driver : Role.parent,
        child: child ?? const SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();

    final seen = switch (answer.state) {
      PlatformState.ok => 'ok',
      PlatformState.notice => 'notice',
      PlatformState.maintenance => 'maintenance',
    };
    debugPrint('PROBE $_role parsed=$seen title=${answer.title} ends=${answer.endsAt}');
    expect(seen, onTheWire, reason: 'the app read the live answer differently from the wire');

    switch (answer.state) {
      case PlatformState.ok:
        expect(find.text(_homeText), findsOneWidget);
        expect(find.byType(StatusNotice), findsNothing);
        expect(find.byType(MaintenanceScreen), findsNothing);
      case PlatformState.notice:
        expect(find.byType(StatusNotice), findsOneWidget);
        expect(find.text(answer.title!), findsOneWidget);
        expect(find.text(answer.message!), findsOneWidget);
        expect(find.text(_homeText), findsOneWidget);
        await tester.tap(find.text(t('common.close')));
        await tester.pumpAndSettle();
        expect(find.byType(StatusNotice), findsNothing);
      case PlatformState.maintenance:
        expect(find.byType(MaintenanceScreen), findsOneWidget);
        expect(find.text(answer.title!), findsOneWidget);
        expect(find.text(answer.message!), findsOneWidget);
        expect(find.text(_homeText), findsNothing);
        expect(find.byType(Navigator), findsNothing);
        expect(await tester.binding.handlePopRoute(), isTrue);
        expect(find.byType(MaintenanceScreen), findsOneWidget);
    }
  });
}
