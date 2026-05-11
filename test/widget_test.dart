import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/models/category.dart';
import 'package:passstore/core/models/vault_entry.dart';
import 'package:passstore/core/services/vault_merge.dart';
import 'package:passstore/core/services/vault_service.dart';
import 'package:passstore/data/app_preferences.dart';
import 'package:passstore/data/webdav_settings.dart';
import 'package:passstore/features/app_shell.dart';
import 'package:passstore/features/screens/change_master_password_dialog.dart';
import 'package:passstore/features/screens/category_manager_screen.dart';
import 'package:passstore/features/screens/create_vault_screen.dart';
import 'package:passstore/features/screens/edit_entry_dialog.dart';
import 'package:passstore/features/screens/main_vault_screen.dart';
import 'package:passstore/features/screens/recycle_bin_screen.dart';
import 'package:passstore/features/screens/settings_screen.dart';
import 'package:passstore/features/screens/sync_conflict_dialog.dart';
import 'package:passstore/features/screens/unlock_screen.dart';
import 'package:passstore/main.dart';

void main() {
  testWidgets('shows PassStore create vault flow', (tester) async {
    await tester.pumpWidget(const PassStoreApp());

    expect(find.text('PassStore'), findsOneWidget);
    expect(find.text('创建密码库'), findsWidgets);
  });

  testWidgets('app theme keeps dialogs on the neutral white surface', (
    tester,
  ) async {
    await tester.pumpWidget(const PassStoreApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final theme = app.theme!;

    expect(theme.dialogTheme.backgroundColor, Colors.white);
    expect(theme.dialogTheme.surfaceTintColor, Colors.white);
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

  testWidgets('unlock password field autofocuses on open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: UnlockScreen(onUnlock: (_) async {})),
    );

    final passwordField = tester.widget<TextField>(find.byType(TextField));

    expect(passwordField.autofocus, isTrue);
  });

  testWidgets('pressing Enter submits the unlock password', (tester) async {
    String? submittedPassword;

    await tester.pumpWidget(
      MaterialApp(
        home: UnlockScreen(
          onUnlock: (password) async {
            submittedPassword = password;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'master-password');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(submittedPassword, 'master-password');
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

  testWidgets('main vault row uses category icon and omits category chip', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 5, 12);
    var vault = VaultService.createEmptyVault(now: now);
    final websiteEntry = VaultEntry.create(
      title: '坚果云',
      account: 'user@example.com',
      password: 'secret',
      url: 'https://www.jianguoyun.com',
      notes: '',
      categoryId: Category.websiteId,
      now: now,
    );
    vault = VaultService.upsertEntry(vault, websiteEntry, now: now);

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

    final entryTile = tester.widget<ListTile>(
      find
          .ancestor(of: find.text('坚果云'), matching: find.byType(ListTile))
          .first,
    );

    expect((entryTile.leading! as Icon).icon, Icons.public);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('category manager exposes a custom category add action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagerScreen(
          categories: Category.builtIns(DateTime.utc(2026, 5, 12)),
          onAdd: (_) {},
          onRename: (_, _) {},
          onDelete: (_) {},
          onBack: () {},
        ),
      ),
    );

    final customHeaderCenter = tester.getCenter(find.text('自定义分类')).dy;
    final emptyStateTop = tester.getTopLeft(find.text('还没有自定义分类')).dy;
    final addButton = find.widgetWithText(FilledButton, '新建自定义分类');
    final addButtonTop = tester.getTopLeft(addButton).dy;

    expect(addButtonTop, greaterThan(customHeaderCenter));
    expect(addButtonTop, lessThan(emptyStateTop));
  });

  testWidgets('category manager can add a custom category with save', (
    tester,
  ) async {
    String? addedName;

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagerScreen(
          categories: Category.builtIns(DateTime.utc(2026, 5, 12)),
          onAdd: (name) => addedName = name,
          onRename: (_, _) {},
          onDelete: (_) {},
          onBack: () {},
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '新建自定义分类'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '工作');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(addedName, '工作');
  });

  testWidgets('category manager can add a custom category with Enter', (
    tester,
  ) async {
    String? addedName;

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagerScreen(
          categories: Category.builtIns(DateTime.utc(2026, 5, 12)),
          onAdd: (name) => addedName = name,
          onRename: (_, _) {},
          onDelete: (_) {},
          onBack: () {},
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '新建自定义分类'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '工作');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(addedName, '工作');
  });

  testWidgets('category name dialog uses compact title and equal actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagerScreen(
          categories: Category.builtIns(DateTime.utc(2026, 5, 12)),
          onAdd: (_) {},
          onRename: (_, _) {},
          onDelete: (_) {},
          onBack: () {},
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '新建自定义分类'));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('新建分类'));
    final save = find.widgetWithText(FilledButton, '保存');
    final cancel = find.widgetWithText(OutlinedButton, '取消');

    final saveSize = tester.getSize(save);
    final cancelSize = tester.getSize(cancel);
    final saveLeft = tester.getTopLeft(save).dx;
    final cancelLeft = tester.getTopLeft(cancel).dx;

    expect(title.style?.fontSize, 22);
    expect(saveSize.width, cancelSize.width);
    expect(saveSize.height, cancelSize.height);
    expect(cancelLeft, greaterThan(saveLeft));
  });

  testWidgets('category delete dialog uses compact title and equal actions', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 5, 12);
    final categories = [
      ...Category.builtIns(now),
      Category(
        id: 'custom-test',
        name: '测试',
        sortOrder: 4,
        isBuiltIn: false,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagerScreen(
          categories: categories,
          onAdd: (_) {},
          onRename: (_, _) {},
          onDelete: (_) {},
          onBack: () {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('删除“测试”？'));
    final delete = find.widgetWithText(FilledButton, '删除');
    final cancel = find.widgetWithText(OutlinedButton, '取消');

    final deleteSize = tester.getSize(delete);
    final cancelSize = tester.getSize(cancel);
    final deleteLeft = tester.getTopLeft(delete).dx;
    final cancelLeft = tester.getTopLeft(cancel).dx;

    expect(title.style?.fontSize, 22);
    expect(deleteSize.width, cancelSize.width);
    expect(deleteSize.height, cancelSize.height);
    expect(cancelLeft, greaterThan(deleteLeft));
  });

  testWidgets(
    'recycle bin delete dialog uses compact title and equal actions',
    (tester) async {
      final now = DateTime.utc(2026, 5, 12);
      final entry = VaultEntry.create(
        title: '测试',
        account: 'user@example.com',
        password: 'password',
        url: 'https://example.com',
        notes: '',
        categoryId: Category.websiteId,
        now: now,
      ).copyWith(deletedAt: now);

      await tester.pumpWidget(
        MaterialApp(
          home: RecycleBinScreen(
            entries: [entry],
            onRestore: (_) {},
            onDeleteForever: (_) {},
            onBack: () {},
          ),
        ),
      );

      await tester.tap(find.widgetWithText(TextButton, '永久删除'));
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(find.text('永久删除“测试”？'));
      final delete = find.widgetWithText(FilledButton, '永久删除');
      final cancel = find.widgetWithText(OutlinedButton, '取消');

      final deleteSize = tester.getSize(delete);
      final cancelSize = tester.getSize(cancel);
      final deleteLeft = tester.getTopLeft(delete).dx;
      final cancelLeft = tester.getTopLeft(cancel).dx;

      expect(title.style?.fontSize, 22);
      expect(deleteSize.width, cancelSize.width);
      expect(deleteSize.height, cancelSize.height);
      expect(cancelLeft, greaterThan(deleteLeft));
    },
  );

  testWidgets('sync conflict dialog uses compact title and equal actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SyncConflictDialog(
            conflict: FieldConflict(
              entryId: 'entry-1',
              fieldName: 'password',
              localValue: 'local-password',
              remoteValue: 'remote-password',
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('解决同步冲突'));
    final remote = find.widgetWithText(FilledButton, '选择云端值');
    final local = find.widgetWithText(OutlinedButton, '选择本机值');

    final remoteSize = tester.getSize(remote);
    final localSize = tester.getSize(local);
    final remoteLeft = tester.getTopLeft(remote).dx;
    final localLeft = tester.getTopLeft(local).dx;

    expect(title.style?.fontSize, 22);
    expect(remoteSize.width, localSize.width);
    expect(remoteSize.height, localSize.height);
    expect(localLeft, greaterThan(remoteLeft));
  });

  testWidgets('subpage back buttons leave leading margin', (tester) async {
    Future<double> backButtonLeftFor(Widget child) async {
      await tester.pumpWidget(MaterialApp(home: child));
      final button = find
          .ancestor(
            of: find.byIcon(Icons.arrow_back),
            matching: find.byType(IconButton),
          )
          .first;
      return tester.getTopLeft(button).dx;
    }

    final settingsLeft = await backButtonLeftFor(
      SettingsScreen(
        initialSettings: WebDavSettings.empty,
        initialPreferences: AppPreferences.defaults,
        onSaveWebDav: (_, _, _) async {},
        onTestWebDav: (_, _, _) async => '连接成功',
        onSavePreferences: (_) async {},
        onExportBackup: () async => '备份已导出',
        onImportBackup: () async => '已从备份恢复',
        onChangeMasterPassword: () async {},
        onBack: () {},
      ),
    );
    final categoriesLeft = await backButtonLeftFor(
      CategoryManagerScreen(
        categories: Category.builtIns(DateTime.utc(2026, 5, 12)),
        onAdd: (_) {},
        onRename: (_, _) {},
        onDelete: (_) {},
        onBack: () {},
      ),
    );
    final recycleLeft = await backButtonLeftFor(
      RecycleBinScreen(
        entries: const [],
        onRestore: (_) {},
        onDeleteForever: (_) {},
        onBack: () {},
      ),
    );

    expect(settingsLeft, greaterThanOrEqualTo(16));
    expect(categoriesLeft, greaterThanOrEqualTo(16));
    expect(recycleLeft, greaterThanOrEqualTo(16));
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
          preferences: AppPreferences.defaults,
          onVaultChanged: (_) async {},
          onMasterPasswordChanged: (_, _) async {},
          onSaveWebDav: (_, _, _) async {},
          onPreferencesChanged: (_) async {},
          onExportBackup: () async => '备份已导出',
          onImportBackup: () async => '已从备份恢复',
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
          preferences: AppPreferences.defaults,
          onVaultChanged: (_) async {},
          onMasterPasswordChanged: (_, _) async {},
          onSaveWebDav: (_, _, _) async {},
          onPreferencesChanged: (_) async {},
          onExportBackup: () async => '备份已导出',
          onImportBackup: () async => '已从备份恢复',
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
          preferences: AppPreferences.defaults,
          onVaultChanged: (_) async {},
          onMasterPasswordChanged: (_, _) async {},
          onSaveWebDav: (_, _, _) async {},
          onPreferencesChanged: (_) async {},
          onExportBackup: () async => '备份已导出',
          onImportBackup: () async => '已从备份恢复',
          onLock: () {},
        ),
      ),
    );

    expect(find.text('未配置同步'), findsOneWidget);
    expect(find.text('已同步'), findsNothing);
  });

  testWidgets('app shell locks after the configured inactivity delay', (
    tester,
  ) async {
    final vault = VaultService.createEmptyVault(now: DateTime.utc(2026, 5, 12));
    var lockCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          vault: vault,
          masterPassword: 'master-password',
          encryptedPayload: null,
          webDavSettings: WebDavSettings.empty,
          preferences: const AppPreferences(
            autoLockMinutes: 1,
            clipboardClearSeconds: 30,
          ),
          onVaultChanged: (_) async {},
          onMasterPasswordChanged: (_, _) async {},
          onSaveWebDav: (_, _, _) async {},
          onPreferencesChanged: (_) async {},
          onExportBackup: () async => '备份已导出',
          onImportBackup: () async => '已从备份恢复',
          onLock: () => lockCount++,
        ),
      ),
    );

    await tester.pump(const Duration(minutes: 1, seconds: 1));

    expect(lockCount, 1);
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

  testWidgets('entry copy clears clipboard after configured delay', (
    tester,
  ) async {
    var clipboardText = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final data = (call.arguments as Map<Object?, Object?>);
          clipboardText = data['text']! as String;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return {'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final now = DateTime.utc(2026, 5, 11);
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
            categories: Category.builtIns(now),
            initialCategoryId: Category.websiteId,
            entry: entry,
            clipboardClearSeconds: 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('复制密码'));
    await tester.pump();

    var data = await Clipboard.getData(Clipboard.kTextPlain);
    expect(data?.text, 'plain-secret');

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    data = await Clipboard.getData(Clipboard.kTextPlain);
    expect(data?.text, '');
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

  testWidgets('entry dialog uses compact title and equal action buttons', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 5, 12);

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

    final title = tester.widget<Text>(find.text('新建条目'));
    final saveSize = tester.getSize(find.widgetWithText(FilledButton, '保存'));
    final cancelSize = tester.getSize(
      find.widgetWithText(OutlinedButton, '取消'),
    );
    final saveLeft = tester
        .getTopLeft(find.widgetWithText(FilledButton, '保存'))
        .dx;
    final cancelLeft = tester
        .getTopLeft(find.widgetWithText(OutlinedButton, '取消'))
        .dx;

    expect(title.style?.fontSize, 22);
    expect(saveSize.height, cancelSize.height);
    expect(saveSize.width, cancelSize.width);
    expect(cancelLeft, greaterThan(saveLeft));
  });

  testWidgets('change master password dialog uses the shared action layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChangeMasterPasswordDialog())),
    );

    final confirmSize = tester.getSize(
      find.widgetWithText(FilledButton, '确认修改'),
    );
    final cancelSize = tester.getSize(
      find.widgetWithText(OutlinedButton, '取消'),
    );
    final confirmLeft = tester
        .getTopLeft(find.widgetWithText(FilledButton, '确认修改'))
        .dx;
    final cancelLeft = tester
        .getTopLeft(find.widgetWithText(OutlinedButton, '取消'))
        .dx;

    expect(confirmSize.height, cancelSize.height);
    expect(confirmSize.width, cancelSize.width);
    expect(cancelLeft, greaterThan(confirmLeft));
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
          initialPreferences: AppPreferences.defaults,
          onSaveWebDav: (_, _, _) async {},
          onTestWebDav: (_, _, _) async => '连接失败 401',
          onSavePreferences: (_) async {},
          onExportBackup: () async => '备份已导出',
          onImportBackup: () async => '已从备份恢复',
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
          initialPreferences: AppPreferences.defaults,
          onSaveWebDav: (url, account, appPassword) async {
            savedUrl = url;
            savedAccount = account;
            savedPassword = appPassword;
          },
          onTestWebDav: (_, _, _) async => '连接成功',
          onSavePreferences: (_) async {},
          onExportBackup: () async => '备份已导出',
          onImportBackup: () async => '已从备份恢复',
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

  testWidgets('auto lock uses a compact setting control', (tester) async {
    final saved = <AppPreferences>[];

    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          initialSettings: WebDavSettings.empty,
          initialPreferences: AppPreferences.defaults,
          onSaveWebDav: (_, _, _) async {},
          onTestWebDav: (_, _, _) async => '连接成功',
          onSavePreferences: (preferences) async => saved.add(preferences),
          onExportBackup: () async => '备份已导出',
          onImportBackup: () async => '已从备份恢复',
          onChangeMasterPassword: () async {},
          onBack: () {},
        ),
      ),
    );

    expect(find.text('剪贴板清空时间'), findsNothing);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(find.byType(DropdownButton<int>), findsNothing);

    final autoLockControl = find.byType(SegmentedButton<int>);
    expect(autoLockControl, findsOneWidget);

    await tester.tap(find.text('永不'));
    await tester.pumpAndSettle();

    expect(saved.last.autoLockMinutes, 0);
    expect(
      saved.last.clipboardClearSeconds,
      AppPreferences.defaults.clipboardClearSeconds,
    );
    expect(find.text('安全设置已保存'), findsOneWidget);
  });

  testWidgets('backup actions call export and import callbacks', (
    tester,
  ) async {
    var exported = false;
    var imported = false;

    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          initialSettings: WebDavSettings.empty,
          initialPreferences: AppPreferences.defaults,
          onSaveWebDav: (_, _, _) async {},
          onTestWebDav: (_, _, _) async => '连接成功',
          onSavePreferences: (_) async {},
          onExportBackup: () async {
            exported = true;
            return '备份已导出';
          },
          onImportBackup: () async {
            imported = true;
            return '已从备份恢复';
          },
          onChangeMasterPassword: () async {},
          onBack: () {},
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '导出加密备份'));
    await tester.pumpAndSettle();

    expect(exported, isTrue);
    expect(find.text('备份已导出'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '从备份恢复'));
    await tester.pumpAndSettle();

    expect(imported, isTrue);
    expect(find.text('已从备份恢复'), findsOneWidget);
  });

  testWidgets('settings about section shows version and author contact', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          initialSettings: WebDavSettings.empty,
          initialPreferences: AppPreferences.defaults,
          onSaveWebDav: (_, _, _) async {},
          onTestWebDav: (_, _, _) async => '连接成功',
          onSavePreferences: (_) async {},
          onExportBackup: () async => '备份已导出',
          onImportBackup: () async => '已从备份恢复',
          onChangeMasterPassword: () async {},
          onBack: () {},
        ),
      ),
    );

    expect(find.text('版本号：1.0.0+0'), findsOneWidget);
    expect(find.text('联系作者：https://github.com/WillGeng-ctrl/PassStore/issues'), findsOneWidget);
  });
}
