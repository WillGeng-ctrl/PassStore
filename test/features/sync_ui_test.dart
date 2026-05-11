import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/models/vault.dart';
import 'package:passstore/core/services/vault_service.dart';
import 'package:passstore/data/app_preferences.dart';
import 'package:passstore/data/webdav_settings.dart';
import 'package:passstore/data/vault_sync_coordinator.dart';
import 'package:passstore/features/app_shell.dart';
import 'package:passstore/features/screens/main_vault_screen.dart';

void main() {
  testWidgets(
    'configured sync starts as not synced until a real sync succeeds',
    (tester) async {
      final vault = VaultService.saveWebDavCredentials(
        _vault(),
        url: 'https://dav.jianguoyun.com/dav/',
        account: 'user@example.com',
        appPassword: 'app-password',
        now: DateTime.utc(2026, 5, 12, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            vault: vault,
            masterPassword: 'password',
            encryptedPayload: null,
            webDavSettings: const WebDavSettings(
              url: 'https://dav.jianguoyun.com/dav/',
              account: 'user@example.com',
              hasAppPassword: true,
            ),
            preferences: AppPreferences.defaults,
            syncStatus: VaultSyncStatus.notSynced,
            onVaultChanged: (_) async {},
            onMasterPasswordChanged: (_, _) async {},
            onSaveWebDav: (_, _, _) async {},
            onPreferencesChanged: (_) async {},
            onExportBackup: () async => '备份已导出',
            onImportBackup: () async => '已从备份恢复',
            onSyncRequested: ({remoteMasterPassword}) async =>
                VaultSyncStatus.synced,
            onLock: () {},
          ),
        ),
      );

      expect(find.text('未同步'), findsOneWidget);
      expect(find.text('已同步'), findsNothing);
    },
  );

  testWidgets('sync badge invokes the sync callback', (tester) async {
    var syncCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MainVaultScreen(
          vault: _vault(),
          syncStatus: '未同步',
          onSync: () async {
            syncCount += 1;
          },
          onNewEntry: (_) {},
          onEditEntry: (_) {},
          onDeleteEntry: (_) {},
          onOpenSettings: () {},
          onOpenCategories: () {},
          onOpenRecycleBin: () {},
          onLock: () {},
        ),
      ),
    );

    await tester.tap(find.text('未同步'));
    await tester.pump();

    expect(syncCount, 1);
  });
}

Vault _vault() => VaultService.createEmptyVault(now: DateTime.utc(2026, 5, 12));
