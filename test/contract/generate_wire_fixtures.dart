import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'wire_samples.dart';

/// Saves what this version of the app sends other phones, under
/// test/fixtures/wire/(version)/, for later versions to be tested against.
/// Run it when releasing a version whose formats changed:
///
///   flutter test test/contract/generate_wire_fixtures.dart
///
/// It never replaces a version already saved.
void main() {
  test('save this version\'s wire formats', () async {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version =
        RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(pubspec)!
            .group(1)!;
    final dir = Directory('test/fixtures/wire/$version');
    if (dir.existsSync()) {
      markTestSkipped('$version is already saved; not replacing it.');
      return;
    }
    dir.createSync(recursive: true);
    for (final entry in (await currentWireFormats()).entries) {
      File('${dir.path}/${entry.key}').writeAsStringSync(entry.value);
    }
  });
}
