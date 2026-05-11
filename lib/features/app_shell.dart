import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/models/vault.dart';
import '../core/models/vault_entry.dart';
import '../core/services/vault_crypto.dart';
import '../core/services/vault_service.dart';
import '../data/webdav_settings.dart';
import '../data/webdav_sync_service.dart';
import 'screens/category_manager_screen.dart';
import 'screens/change_master_password_dialog.dart';
import 'screens/edit_entry_dialog.dart';
import 'screens/main_vault_screen.dart';
import 'screens/recycle_bin_screen.dart';
import 'screens/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.vault,
    required this.masterPassword,
    required this.encryptedPayload,
    required this.webDavSettings,
    required this.onVaultChanged,
    required this.onMasterPasswordChanged,
    required this.onSaveWebDav,
    required this.onLock,
  });

  final Vault vault;
  final String masterPassword;
  final EncryptedVaultPayload? encryptedPayload;
  final WebDavSettings webDavSettings;
  final Future<void> Function(Vault vault) onVaultChanged;
  final Future<void> Function(String currentPassword, String nextPassword) onMasterPasswordChanged;
  final Future<void> Function(String url, String account, String appPassword) onSaveWebDav;
  final VoidCallback onLock;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late Vault _vault = widget.vault;
  _ShellView _view = _ShellView.main;

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vault != widget.vault) _vault = widget.vault;
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (_view) {
      _ShellView.main => MainVaultScreen(
          vault: _vault,
          syncStatus: '已同步',
          onNewEntry: _newEntry,
          onEditEntry: _editEntry,
          onDeleteEntry: _deleteEntry,
          onOpenSettings: () => setState(() => _view = _ShellView.settings),
          onOpenCategories: () => setState(() => _view = _ShellView.categories),
          onOpenRecycleBin: () => setState(() => _view = _ShellView.recycleBin),
          onLock: widget.onLock,
        ),
      _ShellView.categories => CategoryManagerScreen(
          categories: _vault.categories,
          onAdd: _addCategory,
          onRename: _renameCategory,
          onDelete: _deleteCategory,
          onBack: () => setState(() => _view = _ShellView.main),
        ),
      _ShellView.recycleBin => RecycleBinScreen(
          entries: _vault.entries.where((entry) => entry.isDeleted).toList(),
          onRestore: _restoreEntry,
          onDeleteForever: _deleteForever,
          onBack: () => setState(() => _view = _ShellView.main),
        ),
      _ShellView.settings => SettingsScreen(
          initialSettings: widget.webDavSettings,
          onSaveWebDav: widget.onSaveWebDav,
          onTestWebDav: _testWebDav,
          onChangeMasterPassword: _changeMasterPassword,
          onBack: () => setState(() => _view = _ShellView.main),
        ),
    };
    return Scaffold(body: child);
  }

  Future<void> _newEntry(String categoryId) async {
    final draft = await showDialog<EntryDraft>(
      context: context,
      builder: (context) => EditEntryDialog(
        categories: _vault.categories,
        initialCategoryId: categoryId,
      ),
    );
    if (draft == null) return;
    final now = DateTime.now().toUtc();
    final entry = VaultEntry.create(
      title: draft.title,
      account: draft.account,
      password: draft.password,
      url: draft.url,
      notes: draft.notes,
      categoryId: draft.categoryId,
      now: now,
    );
    await _update(VaultService.upsertEntry(_vault, entry, now: now));
  }

  Future<void> _editEntry(VaultEntry entry) async {
    final draft = await showDialog<EntryDraft>(
      context: context,
      builder: (context) => EditEntryDialog(
        categories: _vault.categories,
        initialCategoryId: entry.categoryId,
        entry: entry,
      ),
    );
    if (draft == null) return;
    final now = DateTime.now().toUtc();
    final next = entry.copyWith(
      title: draft.title,
      account: draft.account,
      password: draft.password,
      url: draft.url,
      notes: draft.notes,
      categoryId: draft.categoryId,
    );
    await _update(VaultService.upsertEntry(_vault, next, now: now));
  }

  Future<void> _deleteEntry(String entryId) async {
    await _update(VaultService.deleteEntry(_vault, entryId: entryId, now: DateTime.now().toUtc()));
  }

  Future<void> _restoreEntry(String entryId) async {
    await _update(VaultService.restoreEntry(_vault, entryId: entryId, now: DateTime.now().toUtc()));
  }

  Future<void> _deleteForever(String entryId) async {
    await _update(VaultService.permanentlyDeleteEntry(_vault, entryId: entryId, now: DateTime.now().toUtc()));
  }

  Future<void> _addCategory(String name) async {
    await _update(VaultService.addCategory(_vault, name: name, now: DateTime.now().toUtc()));
  }

  Future<void> _renameCategory(String id, String name) async {
    await _update(VaultService.renameCategory(_vault, categoryId: id, name: name, now: DateTime.now().toUtc()));
  }

  Future<void> _deleteCategory(String id) async {
    await _update(VaultService.deleteCategory(_vault, categoryId: id, now: DateTime.now().toUtc()));
  }

  Future<String> _testWebDav(String url, String account, String appPassword) async {
    if (appPassword.isEmpty) return '请输入应用密码后测试连接';
    final result = await const WebDavSyncService().testConnection(url: url, account: account, appPassword: appPassword);
    return result.message;
  }

  Future<void> _changeMasterPassword() async {
    final draft = await showDialog<ChangeMasterPasswordDraft>(
      context: context,
      builder: (context) => const ChangeMasterPasswordDialog(),
    );
    if (draft == null) return;
    await widget.onMasterPasswordChanged(draft.current, draft.next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('主密码已修改')));
    }
  }

  Future<void> _update(Vault vault) async {
    setState(() => _vault = vault);
    await widget.onVaultChanged(vault);
  }

  String debugVaultJson() => jsonEncode(_vault.toJson());
}

enum _ShellView { main, categories, recycleBin, settings }
