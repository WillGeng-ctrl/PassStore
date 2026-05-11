import 'dart:convert';

import 'package:flutter/material.dart';

import 'core/models/vault.dart';
import 'core/services/vault_crypto.dart';
import 'core/services/vault_service.dart';
import 'data/local_vault_repository.dart';
import 'data/webdav_settings.dart';
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

  Vault? _vault;
  EncryptedVaultPayload? _encryptedPayload;
  String? _masterPassword;
  bool _loading = true;
  bool _hasVault = false;
  WebDavSettings _webDavSettings = WebDavSettings.empty;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PassStore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2f6f5e)),
        scaffoldBackgroundColor: const Color(0xfff6f7f4),
        inputDecorationTheme: const InputDecorationTheme(isDense: true),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xffd9ded5))),
        ),
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
        onVaultChanged: _persistVault,
        onMasterPasswordChanged: _changeMasterPassword,
        onSaveWebDav: _saveWebDav,
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
      final payload = await _repository.readEncrypted();
      setState(() {
        _webDavSettings = settings;
        _encryptedPayload = payload;
        _hasVault = payload != null;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _createVault(String masterPassword) async {
    final vault = VaultService.createEmptyVault(now: DateTime.now().toUtc());
    final payload = await _crypto.encryptString(
      plaintext: jsonEncode(vault.toJson()),
      masterPassword: masterPassword,
    );
    if (widget.enablePersistence) await _repository.writeEncrypted(payload);
    setState(() {
      _vault = vault;
      _masterPassword = masterPassword;
      _encryptedPayload = payload;
      _hasVault = true;
    });
  }

  Future<void> _unlockVault(String masterPassword) async {
    final payload = _encryptedPayload ?? await _repository.readEncrypted();
    if (payload == null) throw const VaultCryptoException('没有可解锁的密码库');
    final plaintext = await _crypto.decryptString(payload, masterPassword: masterPassword);
    final vault = Vault.fromJson((jsonDecode(plaintext) as Map<String, Object?>).cast<String, Object?>());
    setState(() {
      _vault = vault;
      _masterPassword = masterPassword;
      _encryptedPayload = payload;
      _hasVault = true;
    });
  }

  Future<void> _persistVault(Vault vault) async {
    final password = _masterPassword;
    if (password == null) return;
    final payload = await _crypto.encryptString(
      plaintext: jsonEncode(vault.toJson()),
      masterPassword: password,
    );
    if (widget.enablePersistence) await _repository.writeEncrypted(payload);
    setState(() {
      _vault = vault;
      _encryptedPayload = payload;
    });
  }

  Future<void> _changeMasterPassword(String currentPassword, String nextPassword) async {
    final payload = _encryptedPayload;
    final vault = _vault;
    if (payload == null || vault == null) throw const VaultCryptoException('没有可修改的密码库');
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
  }

  Future<void> _saveWebDav(String url, String account, String appPassword) async {
    if (widget.enablePersistence) {
      await _settingsStore.save(url: url, account: account, appPassword: appPassword);
    }
    setState(() {
      _webDavSettings = WebDavSettings(
        url: url,
        account: account,
        hasAppPassword: appPassword.isNotEmpty || _webDavSettings.hasAppPassword,
      );
    });
  }

  void _lock() {
    setState(() {
      _vault = null;
      _masterPassword = null;
      _hasVault = true;
    });
  }
}
