import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/models/category.dart';
import 'package:passstore/core/models/vault_entry.dart';
import 'package:passstore/core/services/vault_service.dart';
import 'package:passstore/data/webdav_settings.dart';
import 'package:passstore/features/app_shell.dart';
import 'package:passstore/features/screens/create_vault_screen.dart';
import 'package:passstore/features/screens/edit_entry_dialog.dart';
import 'package:passstore/features/screens/main_vault_screen.dart';
import 'package:passstore/features/screens/settings_screen.dart';
import 'package:passstore/features/screens/unlock_screen.dart';
import 'package:passstore/main.dart';

void main() {
  testWidgets('shows PassStore create vault flow', (tester) async {
    await tester.pumpWidget(const PassStoreApp());

    expect(find.text('PassStore'), findsOneWidget);
    expect(find.text('创建密码库'), findsWidgets);
  });

  testWidgets('unlock error does not move the unlock button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UnlockScreen(
          onUnlock: (_) async => throw Exception('wrong password'),
        ),
      ),
    );

    final button = find.widgetWithText(FilledButton, '解锁');
    final before = tester.getTopLeft(button);

    await tester.enterText(find.byType(TextField), 'bad-password');
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('主密码不正确'), findsOneWidget);
    expect(tester.getTopLeft(button), before);
  });

  testWidgets('create vault validation error does not move the create button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CreateVaultScreen(onCreate: (_) async {})),
    );

    final button = find.widgetWithText(FilledButton, '创建密码库');
    final before = tester.getTopLeft(button);

    await tester.tap(button);
    await tester.pump();

    expect(find.text('主密码至少需要 8 位'), findsOneWidget);
    expect(tester.getTopLeft(button), before);
  });

  testWidgets('main vault screen has one new entry action', (tester) async {
    final vault = VaultService.createEmptyVault(now: DateTime.utc(2026, 5, 11));

    await tester.pumpWidget(
      MaterialApp(
        home: MainVaultScreen(
          vault: vault,
          syncStatus: '未配置同步',
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

    expect(find.widgetWithText(FilledButton, '新建条目'), findsOneWidget);
  });

  testWidgets('unconfigured WebDAV settings show unconfigured sync status', (
    tester,
  ) async {
    final vault = VaultService.createEmptyVault(now: DateTime.utc(2026, 5, 11));

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          vault: vault,
          masterPassword: 'master-password',
          encryptedPayload: null,
          webDavSettings: WebDavSettings.empty,
          onVaultChanged: (_) async {},
          onMasterPasswordChanged: (_, _) async {},
          onSaveWebDav: (_, _, _) async {},
          onLock: () {},
        ),
      ),
    );

    expect(find.text('未配置同步'), findsOneWidget);
    expect(find.text('已同步'), findsNothing);
  });

  testWidgets('WebDAV credentials stored in vault drive sync status', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 5, 12);
    var vault = VaultService.createEmptyVault(now: now);
    vault = VaultService.saveWebDavCredentials(
      vault,
      url: 'https://dav.jianguoyun.com/dav/',
      account: 'user@example.com',
      appPassword: 'encrypted-in-vault',
      now: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          vault: vault,
          masterPassword: 'master-password',
          encryptedPayload: null,
          webDavSettings: WebDavSettings.empty,
          onVaultChanged: (_) async {},
          onMasterPasswordChanged: (_, _) async {},
          onSaveWebDav: (_, _, _) async {},
          onLock: () {},
        ),
      ),
    );

    expect(find.text('已同步'), findsOneWidget);
    expect(find.text('未配置同步'), findsNothing);
  });

  testWidgets('local WebDAV metadata alone does not count as configured', (
    tester,
  ) async {
    final vault = VaultService.createEmptyVault(now: DateTime.utc(2026, 5, 12));

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          vault: vault,
          masterPassword: 'master-password',
          encryptedPayload: null,
          webDavSettings: const WebDavSettings(
            url: 'https://dav.jianguoyun.com/dav/',
            account: 'user@example.com',
            hasAppPassword: true,
          ),
          onVaultChanged: (_) async {},
          onMasterPasswordChanged: (_, _) async {},
          onSaveWebDav: (_, _, _) async {},
          onLock: () {},
        ),
      ),
    );

    expect(find.text('未配置同步'), findsOneWidget);
    expect(find.text('已同步'), findsNothing);
  });

  testWidgets('entry dialog shows password in plain text by default', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 5, 11);
    final categories = Category.builtIns(now);
    final entry = VaultEntry.create(
      title: 'GitHub',
      account: 'user@example.com',
      password: 'plain-secret',
      url: 'https://github.com',
      notes: '',
      categoryId: Category.websiteId,
      now: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditEntryDialog(
            categories: categories,
            initialCategoryId: Category.websiteId,
            entry: entry,
          ),
        ),
      ),
    );

    final passwordField = tester
        .widgetList<TextField>(find.byType(TextField))
        .singleWhere((field) => field.decoration?.labelText == '密码');

    expect(passwordField.obscureText, isFalse);
  });

  testWidgets('entry dialog uses inline category choices', (tester) async {
    final now = DateTime.utc(2026, 5, 11);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditEntryDialog(
            categories: Category.builtIns(now),
            initialCategoryId: Category.websiteId,
          ),
        ),
      ),
    );

    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(ChoiceChip), findsNWidgets(4));
  });

  testWidgets('WebDAV test failure appears below the test button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          initialSettings: WebDavSettings.empty,
          onSaveWebDav: (_, _, _) async {},
          onTestWebDav: (_, _, _) async => '连接失败 401',
          onChangeMasterPassword: () async {},
          onBack: () {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(1), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'bad-app-password');
    await tester.tap(find.widgetWithText(OutlinedButton, '测试连接'));
    await tester.pumpAndSettle();

    final messageTop = tester.getTopLeft(find.text('连接失败 401')).dy;
    final testButtonBottom = tester
        .getBottomLeft(find.widgetWithText(OutlinedButton, '测试连接'))
        .dy;
    final securityTop = tester.getTopLeft(find.text('安全设置')).dy;

    expect(messageTop, greaterThan(testButtonBottom));
    expect(messageTop, lessThan(securityTop));
  });

  testWidgets('WebDAV settings save button is next to connection controls', (
    tester,
  ) async {
    String? savedUrl;
    String? savedAccount;
    String? savedPassword;

    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          initialSettings: WebDavSettings.empty,
          onSaveWebDav: (url, account, appPassword) async {
            savedUrl = url;
            savedAccount = account;
            savedPassword = appPassword;
          },
          onTestWebDav: (_, _, _) async => '连接成功',
          onChangeMasterPassword: () async {},
          onBack: () {},
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField).at(0),
      'https://dav.jianguoyun.com/dav/',
    );
    await tester.enterText(find.byType(TextField).at(1), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'app-password');

    final saveButton = find.widgetWithText(FilledButton, '保存设置');
    final passwordBottom = tester
        .getBottomLeft(find.byType(TextField).at(2))
        .dy;
    final securityTop = tester.getTopLeft(find.text('安全设置')).dy;
    final saveTop = tester.getTopLeft(saveButton).dy;

    expect(saveTop, greaterThan(passwordBottom));
    expect(saveTop, lessThan(securityTop));

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedUrl, 'https://dav.jianguoyun.com/dav/');
    expect(savedAccount, 'user@example.com');
    expect(savedPassword, 'app-password');
    expect(find.text('设置已保存'), findsOneWidget);
  });
}
