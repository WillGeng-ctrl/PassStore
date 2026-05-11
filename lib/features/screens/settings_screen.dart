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
                  trailing: _autoLockSelector(context),
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
                Text(
                  'PassStore',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text('版本号：1.0.0.0'),
                SizedBox(height: 6),
                Text('联系作者：https://github.com/WillGeng-ctrl/PassStore/issues'),
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
          trailing,
        ],
      ),
    );
  }

  Widget _autoLockSelector(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      segments: _autoLockOptions.entries
          .map(
            (entry) =>
                ButtonSegment<int>(value: entry.key, label: Text(entry.value)),
          )
          .toList(),
      selected: {_autoLockMinutes},
      onSelectionChanged: _preferencesBusy
          ? null
          : (selected) {
              final value = selected.first;
              setState(() => _autoLockMinutes = value);
              _savePreferences();
            },
    );
  }
}

const _autoLockOptions = <int, String>{
  0: '永不',
  5: '5 分',
  15: '15 分',
  30: '30 分',
  60: '1 小时',
};
