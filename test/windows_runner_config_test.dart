import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows runner uses the branded executable name', () {
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();
    final rc = File('windows/runner/Runner.rc').readAsStringSync();

    expect(cmake, contains('set(BINARY_NAME "PassStore")'));
    expect(rc, contains('VALUE "FileDescription", "PassStore"'));
    expect(rc, contains('VALUE "InternalName", "PassStore"'));
    expect(rc, contains('VALUE "OriginalFilename", "PassStore.exe"'));
    expect(rc, contains('VALUE "ProductName", "PassStore"'));
  });

  test('Windows runner centers the startup window in logical coordinates', () {
    final main = File('windows/runner/main.cpp').readAsStringSync();

    expect(
      main,
      contains('FlutterDesktopGetDpiForMonitor(primary_monitor) / 96.0'),
    );
    expect(main, contains('origin_x / dpi_scale'));
    expect(main, contains('origin_y / dpi_scale'));
  });
}
