import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/offline_cache.dart';

const _channel = MethodChannel('plugins.flutter.io/path_provider');

Directory? _temp;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    _temp = await Directory.systemTemp.createTemp('ksp_cache_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async => _temp!.path);
    await OfflineCache.instance.clear();
  });

  tearDown(() async {
    await OfflineCache.instance.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    if (_temp != null && await _temp!.exists()) await _temp!.delete(recursive: true);
  });

  test('what was saved comes back, with the time it was saved', () async {
    await OfflineCache.instance.write('/parent/children', [
      {'studentId': 'a', 'name': 'Shadan'},
    ]);

    final back = await OfflineCache.instance.read('/parent/children');

    expect(back, isNotNull);
    expect((back!.value as List).first['name'], 'Shadan');
    expect(
      DateTime.now().difference(back.savedAt).inMinutes,
      lessThan(2),
      reason: 'the banner tells the parent how old this is, so the stamp must be real',
    );
  });

  test('a key that was never saved reads as nothing, not as empty data', () async {
    expect(await OfflineCache.instance.read('/parent/fees'), isNull);
  });

  test('signing out takes the cache with it', () async {
    await OfflineCache.instance.write('/parent/children', [
      {'studentId': 'a'},
    ]);
    expect(await OfflineCache.instance.read('/parent/children'), isNotNull);

    await OfflineCache.instance.clear();

    expect(
      await OfflineCache.instance.read('/parent/children'),
      isNull,
      reason: 'a handed-over phone must not keep another family\'s child on it',
    );
  });

  test('anything older than a fortnight is dropped rather than shown', () async {
    await OfflineCache.instance.write('/parent/announcements', [1, 2, 3]);

    final dir = Directory('${_temp!.path}/parent_cache');
    final file = dir.listSync().whereType<File>().first;
    final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    decoded['savedAt'] =
        DateTime.now().toUtc().subtract(const Duration(days: 15)).toIso8601String();
    await file.writeAsString(jsonEncode(decoded));

    expect(
      await OfflineCache.instance.read('/parent/announcements'),
      isNull,
      reason: 'two week old school news is worse than saying there is none',
    );
  });

  test('a corrupted file reads as nothing instead of throwing at the screen', () async {
    await OfflineCache.instance.write('/parent/fees', {'total': 1});
    final dir = Directory('${_temp!.path}/parent_cache');
    await dir.listSync().whereType<File>().first.writeAsString('{ this is not json');

    expect(await OfflineCache.instance.read('/parent/fees'), isNull);
  });

  test('nothing that moves is ever kept on the phone', () {
    final source = File('lib/api/parent_api.dart').readAsStringSync();

    final kept = RegExp(r"_keepable(?:<[^>]*>)?\(\s*'([^']+)'")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toList();

    expect(kept, isNotEmpty, reason: 'the cache must actually be wired to something');

    const forbidden = [
      'live',
      'position',
      'track',
      'home-arrivals',
      'consents',
      'concerns',
      'safety',
    ];

    for (final path in kept) {
      for (final word in forbidden) {
        expect(
          path.contains(word),
          isFalse,
          reason: 'caching $path replays a decision that has already expired; '
              'a bus position or a pending consent must never be served from disk',
        );
      }
    }
  });
}
