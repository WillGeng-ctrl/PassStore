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
}
