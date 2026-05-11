import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/data/webdav_settings.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('passstore-settings-test-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saves WebDAV metadata without persisting the app password', () async {
    final store = WebDavSettingsStore(baseDirectory: tempDir);

    await store.saveMetadata(
      url: 'https://dav.jianguoyun.com/dav/',
      account: 'user@example.com',
      hasAppPassword: true,
    );

    final settingsFile = File(
      '${tempDir.path}${Platform.pathSeparator}settings.json',
    );
    final json =
        jsonDecode(await settingsFile.readAsString()) as Map<String, Object?>;

    expect(json['url'], 'https://dav.jianguoyun.com/dav/');
    expect(json['account'], 'user@example.com');
    expect(json['hasAppPassword'], isTrue);
    expect(json.containsKey('appPassword'), isFalse);
  });

  test('overwrites old plaintext app password when saving metadata', () async {
    final store = WebDavSettingsStore(baseDirectory: tempDir);
    final settingsFile = File(
      '${tempDir.path}${Platform.pathSeparator}settings.json',
    );
    await settingsFile.writeAsString(
      jsonEncode({
        'url': 'https://dav.jianguoyun.com/dav/',
        'account': 'user@example.com',
        'appPassword': 'legacy-plaintext-password',
      }),
    );

    expect(await store.readLegacyPassword(), 'legacy-plaintext-password');

    await store.saveMetadata(
      url: 'https://dav.jianguoyun.com/dav/',
      account: 'user@example.com',
      hasAppPassword: true,
    );

    final json =
        jsonDecode(await settingsFile.readAsString()) as Map<String, Object?>;
    expect(json.containsKey('appPassword'), isFalse);
    expect((await store.load()).hasAppPassword, isTrue);
  });
}
