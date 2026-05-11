import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  WebDavSettingsStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _urlKey = 'webdav.url';
  static const _accountKey = 'webdav.account';
  static const _passwordKey = 'webdav.appPassword';

  final FlutterSecureStorage _secureStorage;

  Future<WebDavSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final password = await _secureStorage.read(key: _passwordKey);
    return WebDavSettings(
      url: prefs.getString(_urlKey) ?? WebDavSettings.empty.url,
      account: prefs.getString(_accountKey) ?? '',
      hasAppPassword: password != null && password.isNotEmpty,
    );
  }

  Future<String?> readPassword() => _secureStorage.read(key: _passwordKey);

  Future<void> save({
    required String url,
    required String account,
    String? appPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url);
    await prefs.setString(_accountKey, account);
    if (appPassword != null && appPassword.isNotEmpty) {
      await _secureStorage.write(key: _passwordKey, value: appPassword);
    }
  }
}
