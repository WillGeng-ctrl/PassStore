import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/data/app_preferences.dart';

void main() {
  test('loads default preferences when no settings file exists', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'passstore-preferences-',
    );
    addTearDown(() => tempDir.delete(recursive: true));

    final store = AppPreferencesStore(baseDirectory: tempDir);

    final preferences = await store.load();

    expect(preferences.autoLockMinutes, 15);
    expect(preferences.clipboardClearSeconds, 30);
  });

  test('saves and loads security timer preferences', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'passstore-preferences-',
    );
    addTearDown(() => tempDir.delete(recursive: true));

    final store = AppPreferencesStore(baseDirectory: tempDir);

    await store.save(
      const AppPreferences(autoLockMinutes: 0, clipboardClearSeconds: 60),
    );
    final preferences = await store.load();

    expect(preferences.autoLockMinutes, 0);
    expect(preferences.clipboardClearSeconds, 60);
  });
}
