import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/models/strong_password_rules.dart';
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
    expect(preferences.strongPasswordRules, StrongPasswordRules.defaults);
  });

  test('saves and loads security timer preferences', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'passstore-preferences-',
    );
    addTearDown(() => tempDir.delete(recursive: true));

    final store = AppPreferencesStore(baseDirectory: tempDir);

    await store.save(
      const AppPreferences(
        autoLockMinutes: 0,
        clipboardClearSeconds: 60,
        strongPasswordRules: StrongPasswordRules(
          length: 24,
          includeUppercase: true,
          includeLowercase: true,
          includeDigits: true,
          includeSymbols: false,
          excludeAmbiguous: false,
        ),
      ),
    );
    final preferences = await store.load();

    expect(preferences.autoLockMinutes, 0);
    expect(preferences.clipboardClearSeconds, 60);
    expect(preferences.strongPasswordRules.length, 24);
    expect(preferences.strongPasswordRules.includeSymbols, isFalse);
    expect(preferences.strongPasswordRules.excludeAmbiguous, isFalse);
  });
}
