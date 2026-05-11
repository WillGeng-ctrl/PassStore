import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/models/vault.dart';
import 'package:passstore/core/services/vault_service.dart';

void main() {
  test('stores WebDAV credentials inside the vault payload model', () {
    final now = DateTime.utc(2026, 5, 12);
    final vault = VaultService.createEmptyVault(now: now);

    final updated = VaultService.saveWebDavCredentials(
      vault,
      url: ' https://dav.jianguoyun.com/dav/ ',
      account: ' user@example.com ',
      appPassword: ' app-password ',
      now: now,
    );

    final credentials = updated.webDavCredentials;
    expect(credentials, isNotNull);
    expect(credentials!.url, 'https://dav.jianguoyun.com/dav/');
    expect(credentials.account, 'user@example.com');
    expect(credentials.appPassword, 'app-password');

    final decoded = Vault.fromJson(updated.toJson());
    expect(decoded.webDavCredentials!.appPassword, 'app-password');
  });

  test('keeps existing WebDAV app password when saving an empty password', () {
    final now = DateTime.utc(2026, 5, 12);
    var vault = VaultService.createEmptyVault(now: now);
    vault = VaultService.saveWebDavCredentials(
      vault,
      url: 'https://dav.jianguoyun.com/dav/',
      account: 'user@example.com',
      appPassword: 'existing-app-password',
      now: now,
    );

    final updated = VaultService.saveWebDavCredentials(
      vault,
      url: 'https://dav.jianguoyun.com/dav/new/',
      account: 'new@example.com',
      appPassword: '',
      now: now.add(const Duration(minutes: 1)),
    );

    expect(
      updated.webDavCredentials!.url,
      'https://dav.jianguoyun.com/dav/new/',
    );
    expect(updated.webDavCredentials!.account, 'new@example.com');
    expect(updated.webDavCredentials!.appPassword, 'existing-app-password');
  });
}
