import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'core/models/vault.dart';
import 'core/services/vault_crypto.dart';
import 'core/services/vault_service.dart';
import 'data/app_preferences.dart';
import 'data/local_vault_repository.dart';
import 'data/sync_metadata_store.dart';
import 'data/vault_backup_service.dart';
import 'data/webdav_settings.dart';
import 'data/vault_sync_coordinator.dart';
import 'data/webdav_sync_service.dart';
import 'features/app_shell.dart';
import 'features/screens/create_vault_screen.dart';
import 'features/screens/unlock_screen.dart';

void main() {
  runApp(const PassStoreApp(enablePersistence: true));
}

class PassStoreApp extends StatefulWidget {
  const PassStoreApp({super.key, this.enablePersistence = false});

  final bool enablePersistence;

  @override
  State<PassStoreApp> createState() => _PassStoreAppState();
}

class _PassStoreAppState extends State<PassStoreApp> {
  final _crypto = VaultCrypto();
  final _repository = const LocalVaultRepository();
  final _settingsStore = WebDavSettingsStore();
  final _syncMetadataStore = const SyncMetadataStore();
  final _preferencesStore = const AppPreferencesStore();
  final _backupService = const VaultBackupService();
  late final _syncCoordinator = VaultSyncCoordinator(
    crypto: _crypto,
    remote: const WebDavSyncService(),
  );

  Vault? _vault;
  EncryptedVaultPayload? _encryptedPayload;
  String? _masterPassword;
  bool _loading = true;
  bool _hasVault = false;
  WebDavSettings _webDavSettings = WebDavSettings.empty;
  AppPreferences _preferences = AppPreferences.defaults;
  SyncMetadata _syncMetadata = SyncMetadata.empty;
  VaultSyncStatus _syncStatus = VaultSyncStatus.unconfigured;
  Timer? _autoSyncTimer;

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff2563eb),
    );
    return MaterialApp(
      title: 'PassStore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xfff4f6f8),
        fontFamilyFallback: const [
          'Microsoft YaHei UI',
          'Microsoft YaHei',
          'PingFang SC',
          'Hiragino Sans GB',
          'Noto Sans SC',
          'Segoe UI',
          'Arial',
        ],
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xffcbd5e1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xff2563eb), width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff2563eb),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xff1d4ed8),
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xffe2e8f0)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xffe2e8f0)),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final vault = _vault;
    final masterPassword = _masterPassword;
    if (vault != null && masterPassword != null) {
      return AppShell(
        vault: vault,
        masterPassword: masterPassword,
        encryptedPayload: _encryptedPayload,
        webDavSettings: _webDavSettings,
        preferences: _preferences,
        syncStatus: _syncStatus,
        onVaultChanged: _persistVault,
        onMasterPasswordChanged: _changeMasterPassword,
        onSaveWebDav: _saveWebDav,
        onPreferencesChanged: _savePreferences,
        onExportBackup: _exportBackup,
        onImportBackup: _importBackup,
        onSyncRequested: _runSync,
        onLock: _lock,
      );
    }
    if (_hasVault) {
      return UnlockScreen(onUnlock: _unlockVault);
    }
    return CreateVaultScreen(onCreate: _createVault);
  }

  Future<void> _bootstrap() async {
    if (!widget.enablePersistence) {
      setState(() => _loading = false);
      return;
    }
    try {
      final settings = await _settingsStore.load();
      final preferences = await _preferencesStore.load();
      final syncMetadata = await _syncMetadataStore.load();
      final payload = await _repository.readEncrypted();
      setState(() {
        _webDavSettings = settings;
        _preferences = preferences;
        _syncMetadata = syncMetadata;
        _syncStatus = _syncStatusFor(settings, syncMetadata);
        _encryptedPayload = payload;
        _hasVault = payload != null;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _createVault(String masterPassword) async {
    var vault = VaultService.createEmptyVault(now: DateTime.now().toUtc());
    if (widget.enablePersistence) {
      final legacyPassword = await _settingsStore.readLegacyPassword();
      if (legacyPassword != null && legacyPassword.isNotEmpty) {
        vault = VaultService.saveWebDavCredentials(
          vault,
          url: _webDavSettings.url,
          account: _webDavSettings.account,
          appPassword: legacyPassword,
          now: DateTime.now().toUtc(),
        );
      }
    }
    final payload = await _crypto.encryptString(
      plaintext: jsonEncode(vault.toJson()),
      masterPassword: masterPassword,
    );
    final webDavSettings = _webDavSettingsFromVault(vault, _webDavSettings);
    if (widget.enablePersistence) {
      await _repository.writeEncrypted(payload);
      await _settingsStore.saveMetadata(
        url: webDavSettings.url,
        account: webDavSettings.account,
        hasAppPassword: webDavSettings.hasAppPassword,
      );
    }
    setState(() {
      _vault = vault;
      _masterPassword = masterPassword;
      _encryptedPayload = payload;
      _hasVault = true;
      _webDavSettings = webDavSettings;
      _syncStatus = _syncStatusFor(webDavSettings, _syncMetadata);
    });
  }

  Future<void> _unlockVault(String masterPassword) async {
    var payload = _encryptedPayload ?? await _repository.readEncrypted();
    if (payload == null) throw const VaultCryptoException('没有可解锁的密码库');
    final plaintext = await _crypto.decryptString(
      payload,
      masterPassword: masterPassword,
    );
    var vault = Vault.fromJson(
      (jsonDecode(plaintext) as Map<String, Object?>).cast<String, Object?>(),
    );
    if (widget.enablePersistence) {
      final legacyPassword = await _settingsStore.readLegacyPassword();
      if (legacyPassword != null &&
          legacyPassword.isNotEmpty &&
          !(vault.webDavCredentials?.hasAppPassword ?? false)) {
        vault = VaultService.saveWebDavCredentials(
          vault,
          url: _webDavSettings.url,
          account: _webDavSettings.account,
          appPassword: legacyPassword,
          now: DateTime.now().toUtc(),
        );
        payload = await _crypto.encryptString(
          plaintext: jsonEncode(vault.toJson()),
          masterPassword: masterPassword,
        );
        await _repository.writeEncrypted(payload);
      }
    }
    final webDavSettings = _webDavSettingsFromVault(vault, _webDavSettings);
    if (widget.enablePersistence) {
      await _settingsStore.saveMetadata(
        url: webDavSettings.url,
        account: webDavSettings.account,
        hasAppPassword: webDavSettings.hasAppPassword,
      );
    }
    setState(() {
      _vault = vault;
      _masterPassword = masterPassword;
      _encryptedPayload = payload;
      _hasVault = true;
      _webDavSettings = webDavSettings;
      _syncStatus = _syncStatusFor(webDavSettings, _syncMetadata);
    });
    if (widget.enablePersistence && webDavSettings.isConfigured) {
      unawaited(_runSync());
    }
  }

  Future<void> _persistVault(Vault vault, {bool scheduleSync = true}) async {
    final password = _masterPassword;
    if (password == null) return;
    final payload = await _crypto.encryptString(
      plaintext: jsonEncode(vault.toJson()),
      masterPassword: password,
    );
    if (widget.enablePersistence) await _repository.writeEncrypted(payload);
    final webDavSettings = _webDavSettingsFromVault(vault, _webDavSettings);
    setState(() {
      _vault = vault;
      _encryptedPayload = payload;
      _webDavSettings = webDavSettings;
    });
    if (scheduleSync) {
      await _markUnsynced(webDavSettings);
    }
  }

  Future<void> _changeMasterPassword(
    String currentPassword,
    String nextPassword,
  ) async {
    final payload = _encryptedPayload;
    final vault = _vault;
    if (payload == null || vault == null) {
      throw const VaultCryptoException('没有可修改的密码库');
    }
    await _crypto.decryptString(payload, masterPassword: currentPassword);
    final nextPayload = await _crypto.encryptString(
      plaintext: jsonEncode(vault.toJson()),
      masterPassword: nextPassword,
    );
    if (widget.enablePersistence) await _repository.writeEncrypted(nextPayload);
    setState(() {
      _masterPassword = nextPassword;
      _encryptedPayload = nextPayload;
    });
    await _markUnsynced(
      _webDavSettingsFromVault(vault, _webDavSettings),
      scheduleSync: false,
    );
    unawaited(
      _runSyncInternal(
        remoteMasterPassword: currentPassword,
        uploadMasterPassword: nextPassword,
      ),
    );
  }

  Future<void> _saveWebDav(
    String url,
    String account,
    String appPassword,
  ) async {
    final currentVault = _vault;
    WebDavSettings webDavSettings;
    if (currentVault != null) {
      final vault = VaultService.saveWebDavCredentials(
        currentVault,
        url: url,
        account: account,
        appPassword: appPassword,
        now: DateTime.now().toUtc(),
      );
      await _persistVault(vault, scheduleSync: false);
      webDavSettings = _webDavSettingsFromVault(vault, _webDavSettings);
    } else {
      webDavSettings = WebDavSettings(
        url: url,
        account: account,
        hasAppPassword:
            appPassword.isNotEmpty || _webDavSettings.hasAppPassword,
      );
    }
    if (widget.enablePersistence) {
      await _settingsStore.saveMetadata(
        url: webDavSettings.url,
        account: webDavSettings.account,
        hasAppPassword: webDavSettings.hasAppPassword,
      );
    }
    setState(() {
      _webDavSettings = webDavSettings;
      _syncStatus = _syncStatusFor(webDavSettings, _syncMetadata);
    });
    if (currentVault != null) {
      await _markUnsynced(webDavSettings, scheduleSync: false);
    }
  }

  Future<void> _savePreferences(AppPreferences preferences) async {
    if (widget.enablePersistence) await _preferencesStore.save(preferences);
    setState(() => _preferences = preferences);
  }

  Future<String> _exportBackup() async {
    final path = await _pickBackupSavePath();
    if (path == null) return '已取消导出';
    final payload = await _currentEncryptedPayload();
    if (payload == null) return '没有可导出的密码库';
    try {
      await _backupService.exportEncryptedPayload(payload, path);
      return '备份已导出';
    } catch (error) {
      return '导出失败：$error';
    }
  }

  Future<String> _importBackup() async {
    final path = await _pickBackupOpenPath();
    if (path == null) return '已取消恢复';
    final masterPassword = _masterPassword;
    if (masterPassword == null) return '请先解锁密码库';
    try {
      final payload = await _backupService.importEncryptedPayload(path);
      final plaintext = await _crypto.decryptString(
        payload,
        masterPassword: masterPassword,
      );
      final vault = Vault.fromJson(
        (jsonDecode(plaintext) as Map<String, Object?>).cast<String, Object?>(),
      );
      final webDavSettings = _webDavSettingsFromVault(vault, _webDavSettings);
      if (widget.enablePersistence) {
        await _repository.writeEncrypted(payload);
        await _settingsStore.saveMetadata(
          url: webDavSettings.url,
          account: webDavSettings.account,
          hasAppPassword: webDavSettings.hasAppPassword,
        );
      }
      setState(() {
        _vault = vault;
        _encryptedPayload = payload;
        _hasVault = true;
        _webDavSettings = webDavSettings;
      });
      await _markUnsynced(webDavSettings);
      return '已从备份恢复';
    } catch (error) {
      return '恢复失败：$error';
    }
  }

  Future<EncryptedVaultPayload?> _currentEncryptedPayload() async {
    final existing = _encryptedPayload;
    if (existing != null) return existing;
    final vault = _vault;
    final masterPassword = _masterPassword;
    if (vault == null || masterPassword == null) return null;
    final payload = await _crypto.encryptString(
      plaintext: jsonEncode(vault.toJson()),
      masterPassword: masterPassword,
    );
    setState(() => _encryptedPayload = payload);
    return payload;
  }

  Future<String?> _pickBackupSavePath() async {
    final suggestedName = _suggestedBackupFileName();
    if (Platform.isWindows) {
      return _runWindowsFileDialog(
        save: true,
        title: '导出 PassStore 加密备份',
        suggestedName: suggestedName,
      );
    }
    return p.join(_documentsDirectory().path, suggestedName);
  }

  Future<String?> _pickBackupOpenPath() async {
    if (Platform.isWindows) {
      return _runWindowsFileDialog(save: false, title: '选择 PassStore 备份文件');
    }
    return null;
  }

  Future<String?> _runWindowsFileDialog({
    required bool save,
    required String title,
    String? suggestedName,
  }) async {
    final dialogType = save ? 'SaveFileDialog' : 'OpenFileDialog';
    final fileNameLine = suggestedName == null
        ? ''
        : "\$dialog.FileName = '${_escapePowerShell(suggestedName)}'";
    final script =
        '''
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.$dialogType
\$dialog.Title = '${_escapePowerShell(title)}'
\$dialog.Filter = 'PassStore Vault (*.vault)|*.vault|All files (*.*)|*.*'
$fileNameLine
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  [Console]::Out.Write(\$dialog.FileName)
}
''';
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-STA',
      '-Command',
      script,
    ]);
    if (result.exitCode != 0) return null;
    final path = (result.stdout as String).trim();
    return path.isEmpty ? null : path;
  }

  String _escapePowerShell(String value) => value.replaceAll("'", "''");

  String _suggestedBackupFileName() {
    final stamp = DateTime.now()
        .toLocal()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '-');
    return 'passstore-backup-$stamp.vault';
  }

  Directory _documentsDirectory() {
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(p.join(home, 'Documents'));
    }
    return Directory.current;
  }

  WebDavSettings _webDavSettingsFromVault(
    Vault vault,
    WebDavSettings fallback,
  ) {
    final credentials = vault.webDavCredentials;
    if (credentials == null) {
      return fallback.copyWith(hasAppPassword: false);
    }
    return WebDavSettings(
      url: credentials.url.isNotEmpty ? credentials.url : fallback.url,
      account: credentials.account.isNotEmpty
          ? credentials.account
          : fallback.account,
      hasAppPassword: credentials.hasAppPassword,
    );
  }

  Future<VaultSyncStatus> _runSync({String? remoteMasterPassword}) {
    return _runSyncInternal(remoteMasterPassword: remoteMasterPassword);
  }

  Future<VaultSyncStatus> _runSyncInternal({
    String? remoteMasterPassword,
    String? uploadMasterPassword,
  }) async {
    _autoSyncTimer?.cancel();
    final vault = _vault;
    final masterPassword = _masterPassword;
    final credentials = _syncCredentialsFromVault(vault);
    if (vault == null || masterPassword == null || credentials == null) {
      if (mounted) {
        setState(() => _syncStatus = VaultSyncStatus.unconfigured);
      }
      return VaultSyncStatus.unconfigured;
    }

    if (mounted) setState(() => _syncStatus = VaultSyncStatus.syncing);
    final result = await _syncCoordinator.sync(
      localVault: vault,
      masterPassword: masterPassword,
      remoteMasterPassword: remoteMasterPassword,
      uploadMasterPassword: uploadMasterPassword,
      credentials: credentials,
      metadata: _syncMetadata,
    );

    if (!mounted) return result.status;

    if (result.status == VaultSyncStatus.synced) {
      final syncedVault = result.vault!;
      final payload = result.payload!;
      final metadata = result.metadata!;
      final webDavSettings = _webDavSettingsFromVault(
        syncedVault,
        _webDavSettings,
      );
      if (widget.enablePersistence) {
        await _repository.writeEncrypted(payload);
        await _settingsStore.saveMetadata(
          url: webDavSettings.url,
          account: webDavSettings.account,
          hasAppPassword: webDavSettings.hasAppPassword,
        );
        await _syncMetadataStore.save(metadata);
      }
      setState(() {
        _vault = syncedVault;
        _encryptedPayload = payload;
        _masterPassword = result.masterPassword ?? masterPassword;
        _syncMetadata = metadata;
        _webDavSettings = webDavSettings;
        _syncStatus = VaultSyncStatus.synced;
      });
      return VaultSyncStatus.synced;
    }

    final metadata = result.metadata;
    if (metadata != null) await _saveSyncMetadata(metadata);
    setState(() => _syncStatus = result.status);
    return result.status;
  }

  Future<void> _markUnsynced(
    WebDavSettings webDavSettings, {
    bool scheduleSync = true,
  }) async {
    final metadata = _syncMetadata.copyWith(
      hasUnsyncedChanges: true,
      lastError: null,
    );
    await _saveSyncMetadata(metadata);
    if (mounted) {
      setState(() {
        _syncStatus = webDavSettings.isConfigured
            ? VaultSyncStatus.notSynced
            : VaultSyncStatus.unconfigured;
      });
    }
    if (scheduleSync && webDavSettings.isConfigured) _scheduleAutoSync();
  }

  Future<void> _saveSyncMetadata(SyncMetadata metadata) async {
    if (widget.enablePersistence) await _syncMetadataStore.save(metadata);
    if (mounted) setState(() => _syncMetadata = metadata);
  }

  void _scheduleAutoSync() {
    _autoSyncTimer?.cancel();
    if (_syncCredentialsFromVault(_vault) == null) return;
    _autoSyncTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_runSync());
    });
  }

  VaultSyncStatus _syncStatusFor(
    WebDavSettings webDavSettings,
    SyncMetadata metadata,
  ) {
    if (!webDavSettings.isConfigured) return VaultSyncStatus.unconfigured;
    if (metadata.hasUnsyncedChanges) return VaultSyncStatus.notSynced;
    if (metadata.lastSyncedAt != null) return VaultSyncStatus.synced;
    return VaultSyncStatus.notSynced;
  }

  SyncCredentials? _syncCredentialsFromVault(Vault? vault) {
    final credentials = vault?.webDavCredentials;
    if (credentials == null) return null;
    final syncCredentials = SyncCredentials(
      url: credentials.url,
      account: credentials.account,
      appPassword: credentials.appPassword,
    );
    return syncCredentials.isConfigured ? syncCredentials : null;
  }

  void _lock() {
    setState(() {
      _vault = null;
      _masterPassword = null;
      _hasVault = true;
    });
  }
}
