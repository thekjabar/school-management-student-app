import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CachedAt<T> {
  const CachedAt(this.value, this.savedAt);

  final T value;
  final DateTime savedAt;
}

class OfflineCache {
  OfflineCache._();

  static final OfflineCache instance = OfflineCache._();

  static const _folder = 'parent_cache';
  static const _version = 1;
  static const _keepFor = Duration(days: 14);

  Directory? _dir;
  Future<Directory>? _opening;

  final ValueNotifier<DateTime?> savedDataShown = ValueNotifier<DateTime?>(null);

  void servedFromCache(DateTime savedAt) {
    savedDataShown.value = savedAt;
  }

  void servedLive() {
    if (savedDataShown.value != null) savedDataShown.value = null;
  }

  Future<Directory> _directory() {
    final open = _opening ??= () async {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/$_folder');
      if (!await dir.exists()) await dir.create(recursive: true);
      _dir = dir;
      return dir;
    }();
    return open;
  }

  String _fileName(String key) {
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return 'v$_version.$safe.json';
  }

  Future<void> write(String key, Object? value) async {
    try {
      final dir = await _directory();
      final file = File('${dir.path}/${_fileName(key)}');
      final payload = jsonEncode({
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'value': value,
      });
      await file.writeAsString(payload, flush: false);
    } catch (e) {
      debugPrint('offline cache: could not save $key: $e');
    }
  }

  Future<CachedAt<Object?>?> read(String key) async {
    try {
      final dir = await _directory();
      final file = File('${dir.path}/${_fileName(key)}');
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;

      final savedAt = DateTime.tryParse((decoded['savedAt'] ?? '') as String);
      if (savedAt == null) return null;
      if (DateTime.now().toUtc().difference(savedAt.toUtc()) > _keepFor) {
        await file.delete();
        return null;
      }

      return CachedAt<Object?>(decoded['value'], savedAt.toLocal());
    } catch (e) {
      debugPrint('offline cache: could not read $key: $e');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/$_folder');
      if (await dir.exists()) await dir.delete(recursive: true);
      _dir = null;
      _opening = null;
    } catch (e) {
      debugPrint('offline cache: could not clear: $e');
    }
  }

  @visibleForTesting
  Directory? get directoryForTest => _dir;
}
