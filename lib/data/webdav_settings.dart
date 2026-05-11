import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class WebDavSettings {
  const WebDavSettings({
    required this.url,
    required this.account,
    required this.hasAppPassword,
  });

  final String url;
  final String account;
  final bool hasAppPassword;

  bool get isConfigured => url.trim().isNotEmpty && account.trim().isNotEmpty && hasAppPassword;

  WebDavSettings copyWith({
    String? url,
    String? account,
    bool? hasAppPassword,
  }) {
    return WebDavSettings(
      url: url ?? this.url,
      account: account ?? this.account,
      hasAppPassword: hasAppPassword ?? this.hasAppPassword,
    );
  }

  static const empty = WebDavSettings(url: 'https://dav.jianguoyun.com/dav/', account: '', hasAppPassword: false);
}

class WebDavSettingsStore {
  const WebDavSettingsStore();

  Future<WebDavSettings> load() async {
    final file = _settingsFile();
    if (!await file.exists()) return WebDavSettings.empty;
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    final password = json['appPassword'] as String?;
    return WebDavSettings(
      url: json['url'] as String? ?? WebDavSettings.empty.url,
      account: json['account'] as String? ?? '',
      hasAppPassword: password != null && password.isNotEmpty,
    );
  }

  Future<String?> readPassword() async {
    final file = _settingsFile();
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return json['appPassword'] as String?;
  }

  Future<void> save({
    required String url,
    required String account,
    String? appPassword,
  }) async {
    final file = _settingsFile();
    await file.parent.create(recursive: true);
    final existingPassword = await readPassword();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'url': url,
        'account': account,
        'appPassword': appPassword != null && appPassword.isNotEmpty ? appPassword : existingPassword,
      }),
      flush: true,
    );
  }

  File _settingsFile() {
    return File(p.join(_appDataDirectory().path, 'settings.json'));
  }

  Directory _appDataDirectory() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory(p.join(appData, 'PassStore'));
      }
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory(p.join(home, 'Library', 'Application Support', 'PassStore'));
      }
    }
    return Directory(p.join(Directory.current.path, '.passstore'));
  }
}
