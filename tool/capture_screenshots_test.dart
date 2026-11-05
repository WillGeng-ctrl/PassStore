import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/models/category.dart';
import 'package:passstore/core/models/vault_entry.dart';
import 'package:passstore/core/services/vault_service.dart';
import 'package:passstore/data/app_preferences.dart';
import 'package:passstore/data/webdav_settings.dart';
import 'package:passstore/features/screens/main_vault_screen.dart';
import 'package:passstore/features/screens/settings_screen.dart';
import 'package:passstore/features/screens/unlock_screen.dart';
import 'package:passstore/main.dart';

// Render the real pages with fixtures only. Never open a local vault or network.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('render README screenshots with synthetic data', (tester) async {
    final fontPath =
        Platform.environment['PASSSTORE_SCREENSHOT_FONT'] ??
        (Platform.isWindows
            ? r'C:\Windows\Fonts\msyh.ttc'
            : '/System/Library/Fonts/PingFang.ttc');
    if (!File(fontPath).existsSync()) {
      throw StateError('Set PASSSTORE_SCREENSHOT_FONT to a local CJK font.');
    }
    await tester.runAsync(() async {
      final loader = FontLoader('ScreenshotFont')
        ..addFont(
          Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
        );
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const PassStoreApp());
    await tester.pumpAndSettle();
    final baseTheme = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!;
    final theme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'ScreenshotFont'),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(
        fontFamily: 'ScreenshotFont',
      ),
    );
    final output = Directory('docs/screenshots')..createSync(recursive: true);

    Future<void> capture(String name, Widget page, Size size) async {
      tester.view.physicalSize = size;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: page,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${output.path}/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    final now = DateTime.utc(2026, 11, 5, 1);
    final entries = <VaultEntry>[
      VaultEntry.create(
        title: '示例网站',
        account: 'demo@example.com',
        password: 'Demo-Only-Not-A-Real-Password!',
        url: 'https://example.com',
        notes: '仅用于项目截图的虚构演示条目。',
        categoryId: Category.websiteId,
        now: now,
      ),
      VaultEntry.create(
        title: '工作邮箱（演示）',
        account: 'work@example.com',
        password: 'Demo-Only-Not-A-Real-Password!',
        url: 'https://mail.example.com',
        notes: '演示数据，不关联真实邮箱。',
        categoryId: Category.emailId,
        now: now.subtract(const Duration(minutes: 5)),
      ),
      VaultEntry.create(
        title: '笔记应用（演示）',
        account: 'notes@example.com',
        password: 'Demo-Only-Not-A-Real-Password!',
        url: 'https://notes.example.com',
        notes: '演示数据，不关联真实服务。',
        categoryId: Category.appId,
        now: now.subtract(const Duration(minutes: 10)),
      ),
    ];
    final vault = VaultService.createEmptyVault(
      now: now,
    ).copyWith(entries: entries);

    await capture(
      'vault',
      MainVaultScreen(
        vault: vault,
        onNewEntry: (_) {},
        onEditEntry: (_) {},
        onDeleteEntry: (_) {},
        onOpenSettings: () {},
        onOpenCategories: () {},
        onOpenRecycleBin: () {},
        onLock: () {},
        syncStatus: '未配置同步',
      ),
      const Size(1200, 780),
    );
    await capture(
      'unlock',
      UnlockScreen(onUnlock: (_) async {}),
      const Size(1000, 720),
    );
    await capture(
      'settings',
      Scaffold(
        body: SettingsScreen(
          initialSettings: WebDavSettings.empty,
          initialPreferences: AppPreferences.defaults,
          onSaveWebDav: (_, _, _) async {},
          onTestWebDav: (_, _, _) async => '演示模式，不连接网络',
          onSavePreferences: (_) async {},
          onExportBackup: () async => '演示模式，不导出文件',
          onImportBackup: () async => '演示模式，不读取文件',
          onChangeMasterPassword: () async {},
          onBack: () {},
        ),
      ),
      const Size(1200, 1380),
    );
  });
}
