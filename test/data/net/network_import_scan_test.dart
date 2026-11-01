import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Spec §9.2: `lib/data/net/network_gate.dart` is the only file that may
/// import `package:http` or open a socket, so nothing reaches the network
/// without passing the online switches.
void main() {
  test('only the network gate imports package:http or opens a socket', () {
    final offenders = <String>[];
    final forbidden = [
      RegExp(r'''import\s+['"]package:http/'''),
      RegExp(r'\bHttpClient\b'),
      RegExp(r'\b(Raw|Secure|Web)?Socket\b'),
    ];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.replaceAll(r'\', '/') == 'lib/data/net/network_gate.dart') {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        final code = line.trimLeft();
        if (code.startsWith('//')) continue;
        if (forbidden.any((p) => p.hasMatch(code))) {
          offenders.add('${file.path}:${i + 1}: $code');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('the scan would catch an import of package:http', () {
    final pattern = RegExp(r'''import\s+['"]package:http/''');
    expect(pattern.hasMatch("import 'package:http/http.dart' as http;"),
        isTrue);
  });
}
