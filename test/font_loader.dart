import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the SDK keeps the fonts a real device would have.
///
/// Without these every glyph in a golden is a black box: the test binding ships
/// one metric-only font, which is fine for layout assertions and useless for
/// looking at a screen.
Future<void> loadRealFonts() async {
  final root = File(Platform.resolvedExecutable).parent.path;
  var dir = Directory('$root/../cache/artifacts/material_fonts');
  if (!dir.existsSync()) {
    // `flutter test` runs the Dart SDK inside the Flutter cache; walk up until
    // the artifacts folder appears rather than hard-coding a depth.
    var probe = Directory(root);
    for (var i = 0; i < 6 && probe.parent.path != probe.path; i++) {
      final candidate = Directory('${probe.path}/cache/artifacts/material_fonts');
      if (candidate.existsSync()) {
        dir = candidate;
        break;
      }
      probe = probe.parent;
    }
  }
  if (!dir.existsSync()) return;

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final f in files) {
      final file = File('${dir.path}/$f');
      if (!file.existsSync()) continue;
      any = true;
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    if (any) await loader.load();
  }

  await load('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]);
  await load('MaterialIcons', ['materialicons-regular.otf']);
}
