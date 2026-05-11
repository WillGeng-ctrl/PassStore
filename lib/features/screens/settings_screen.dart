import 'package:flutter/material.dart';

import '../../data/app_preferences.dart';
import '../../data/webdav_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.initialSettings,
    required this.initialPreferences,
    required this.onSaveWebDav,
    required this.onTestWebDav,
    required this.onSavePreferences,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.onChangeMasterPassword,
    required this.onBack,
  });

  final WebDavSettings initialSettings;
  final AppPreferences initialPreferences;
  final Future<void> Function(String url, String account, String appPassword)
  onSaveWebDav;
  final Future<String> Function(String url, String account, String appPassword)
  onTestWebDav;
  final Future<void> Function(AppPreferences preferences) onSavePreferences;
  final Future<String> Function() onExportBackup;
  final Future<String> Function() onImportBackup;
  final Future<void> Function() onChangeMasterPassword;
  final VoidCallback onBack;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;
  late final TextEditingController _account;
  final _password = TextEditingController();
  late int _autoLockMinutes;
  String _testMessage = '';
  String _saveMessage = '';
  String _preferencesMessage = '';
  String _backupMessage = '';
  bool _busy = false;
  bool _preferencesBusy = false;
  bool _backupBusy = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.initialSettings.url);
    _account = TextEditingController(text: widget.initialSettings.account);
    _autoLockMinutes = widget.initialPreferences.autoLockMinutes;
  }

  @override
  void dispose() {
    _url.dispose();
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 20),
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                const Text(
                  '设置',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _group('同步设置', [
                TextField(
                  controller: _url,
                  decoration: const InputDecoration(
                    labelText: 'WebDAV 地址',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _account,
                  decoration: const InputDecoration(
                    labelText: '坚果云账号',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: widget.initialSettings.hasAppPassword
                        ? '应用密码（留空则不修改）'
                        : '应用密码',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _test,
                        child: const Text('测试连接'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _save,
                        child: const Text('保存设置'),
                      ),
                    ),
                  ],
                ),
                if (_testMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _testMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (_saveMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _saveMessage,
                    style: const TextStyle(
                      color: Color(0xff079455),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text('云端只保存加密后的 vault 文件，坚果云无法读取密码内容。'),
              ]),
              _group('安全设置', [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('修改主密码'),
                  subtitle: const Text('使用新主密码重新加密本地密码库'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onChangeMasterPassword,
                ),
                const SizedBox(height: 8),
                _compactPreferenceRow(
                  title: '自动锁定时间',
                  subtitle: '无操作后自动回到解锁页',
                  trailing: _autoLockDropdown(context),
                ),
                if (_preferencesMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _preferencesMessage,
                    style: const TextStyle(
                      color: Color(0xff079455),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ]),
              _group('备份与恢复', [
                const Text('备份文件保持加密状态，恢复时需要当前主密码能够解开该备份。'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _backupBusy ? null : _importBackup,
                        child: const Text('从备份恢复'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _backupBusy ? null : _exportBackup,
                        child: const Text('导出加密备份'),
                      ),
                    ),
                  ],
                ),
                if (_backupMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _backupMessage,
                    style: const TextStyle(
                      color: Color(0xff079455),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ]),
              _group('关于', const [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('PassStore'),
                  subtitle: Text('个人自用密码库 MVP'),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _group(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _savePreferences() async {
    setState(() {
      _preferencesBusy = true;
      _preferencesMessage = '';
    });
    await widget.onSavePreferences(
      AppPreferences(
        autoLockMinutes: _autoLockMinutes,
        clipboardClearSeconds: widget.initialPreferences.clipboardClearSeconds,
      ),
    );
    if (mounted) {
      setState(() {
        _preferencesMessage = '安全设置已保存';
        _preferencesBusy = false;
      });
    }
  }

  Future<void> _exportBackup() async {
    await _runBackupAction(widget.onExportBackup);
  }

  Future<void> _importBackup() async {
    await _runBackupAction(widget.onImportBackup);
  }

  Future<void> _runBackupAction(Future<String> Function() action) async {
    setState(() {
      _backupBusy = true;
      _backupMessage = '';
    });
    final message = await action();
    if (mounted) {
      setState(() {
        _backupMessage = message;
        _backupBusy = false;
      });
    }
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _testMessage = '';
      _saveMessage = '';
    });
    final message = await widget.onTestWebDav(
      _url.text,
      _account.text,
      _password.text,
    );
    if (mounted) {
      setState(() {
        _testMessage = message;
        _busy = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _testMessage = '';
      _saveMessage = '';
    });
    await widget.onSaveWebDav(_url.text, _account.text, _password.text);
    if (mounted) {
      setState(() {
        _saveMessage = '设置已保存';
        _busy = false;
      });
    }
  }

  Widget _compactPreferenceRow({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xff64748b),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xffcbd5e1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: trailing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _autoLockDropdown(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: _autoLockMinutes,
        isDense: true,
        itemHeight: kMinInteractiveDimension,
        iconSize: 18,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xff0f172a)),
        items: _autoLockOptions.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: _preferencesBusy
            ? null
            : (value) {
                if (value == null) return;
                setState(() => _autoLockMinutes = value);
                _savePreferences();
              },
      ),
    );
  }
}

const _autoLockOptions = <int, String>{
  0: '永不锁定',
  5: '5 分钟',
  15: '15 分钟',
  30: '30 分钟',
  60: '1 小时',
};
