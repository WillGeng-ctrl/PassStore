import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class AppPreferences {
  const AppPreferences({
    required this.autoLockMinutes,
    required this.clipboardClearSeconds,
  });

  final int autoLockMinutes;
  final int clipboardClearSeconds;

  static const defaults = AppPreferences(
    autoLockMinutes: 15,
    clipboardClearSeconds: 30,
  );

  Duration? get autoLockDelay =>
      autoLockMinutes <= 0 ? null : Duration(minutes: autoLockMinutes);

  Duration? get clipboardClearDelay => clipboardClearSeconds <= 0
      ? null
      : Duration(seconds: clipboardClearSeconds);

  AppPreferences copyWith({int? autoLockMinutes, int? clipboardClearSeconds}) {
    return AppPreferences(
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      clipboardClearSeconds:
          clipboardClearSeconds ?? this.clipboardClearSeconds,
    );
  }

  Map<String, Object?> toJson() => {
    'autoLockMinutes': autoLockMinutes,
    'clipboardClearSeconds': clipboardClearSeconds,
  };

  factory AppPreferences.fromJson(Map<String, Object?> json) {
    return AppPreferences(
      autoLockMinutes:
          json['autoLockMinutes'] as int? ?? defaults.autoLockMinutes,
      clipboardClearSeconds:
          json['clipboardClearSeconds'] as int? ??
          defaults.clipboardClearSeconds,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppPreferences &&
        other.autoLockMinutes == autoLockMinutes &&
        other.clipboardClearSeconds == clipboardClearSeconds;
  }

  @override
  int get hashCode => Object.hash(autoLockMinutes, clipboardClearSeconds);
}

class AppPreferencesStore {
  const AppPreferencesStore({Directory? baseDirectory})
    : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;

  Future<AppPreferences> load() async {
    final file = _preferencesFile();
    if (!await file.exists()) return AppPreferences.defaults;
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return AppPreferences.fromJson(json);
  }

  Future<void> save(AppPreferences preferences) async {
    final file = _preferencesFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(preferences.toJson()),
      flush: true,
    );
  }

  File _preferencesFile() {
    return File(p.join(_appDataDirectory().path, 'preferences.json'));
  }

  Directory _appDataDirectory() {
    final baseDirectory = _baseDirectory;
    if (baseDirectory != null) return baseDirectory;
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory(p.join(appData, 'PassStore'));
      }
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory(
          p.join(home, 'Library', 'Application Support', 'PassStore'),
        );
      }
    }
    return Directory(p.join(Directory.current.path, '.passstore'));
  }
}
