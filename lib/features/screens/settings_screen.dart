import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/strong_password_rules.dart';
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
  late StrongPasswordRules _strongPasswordRules;
  _ConnectionTestStatus _testStatus = _ConnectionTestStatus.idle;
  Timer? _testStatusResetTimer;
  _SaveSettingsStatus _saveStatus = _SaveSettingsStatus.idle;
  Timer? _saveStatusResetTimer;
  _BackupActionStatus _backupStatus = _BackupActionStatus.idle;
  _BackupAction? _backupStatusAction;
  Timer? _backupStatusResetTimer;
  bool _testingWebDav = false;
  bool _savingWebDav = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.initialSettings.url);
    _account = TextEditingController(text: widget.initialSettings.account);
    _autoLockMinutes = widget.initialPreferences.autoLockMinutes;
    _strongPasswordRules = widget.initialPreferences.strongPasswordRules;
  }

  @override
  void dispose() {
    _testStatusResetTimer?.cancel();
    _saveStatusResetTimer?.cancel();
    _backupStatusResetTimer?.cancel();
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
                    Expanded(child: _testConnectionButton()),
                    const SizedBox(width: 12),
                    Expanded(child: _saveSettingsButton()),
                  ],
                ),
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
                const SizedBox(height: 14),
                _strongPasswordRulesSection(context),
              ]),
              _group('备份与恢复', [
                const Text('备份文件保持加密状态，恢复时需要当前主密码能够解开该备份。'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _backupButton(_BackupAction.import)),
                    const SizedBox(width: 12),
                    Expanded(child: _backupButton(_BackupAction.export)),
                  ],
                ),
              ]),
              _group('关于', const [
                Text(
                  'PassStore',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text('版本号：1.0.0+0'),
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
    await widget.onSavePreferences(
      AppPreferences(
        autoLockMinutes: _autoLockMinutes,
        clipboardClearSeconds: widget.initialPreferences.clipboardClearSeconds,
        strongPasswordRules: _strongPasswordRules,
      ),
    );
  }

  Future<void> _exportBackup() async {
    await _runBackupAction(_BackupAction.export, widget.onExportBackup);
  }

  Future<void> _importBackup() async {
    await _runBackupAction(_BackupAction.import, widget.onImportBackup);
  }

  Future<void> _runBackupAction(
    _BackupAction backupAction,
    Future<String> Function() action,
  ) async {
    if (_backupStatus == _BackupActionStatus.running) return;
    _backupStatusResetTimer?.cancel();
    setState(() {
      _backupStatusAction = backupAction;
      _backupStatus = _BackupActionStatus.running;
    });
    final message = await action().catchError(
      (_) => backupAction == _BackupAction.export ? '导出失败' : '恢复失败',
    );
    if (mounted) {
      setState(() {
        _backupStatus = _backupStatusForMessage(message);
      });
      _scheduleBackupStatusReset();
    }
  }

  Widget _backupButton(_BackupAction action) {
    final onPressed =
        _backupStatus == _BackupActionStatus.running &&
            _backupStatusAction == action
        ? null
        : action == _BackupAction.export
        ? _exportBackup
        : _importBackup;

    return switch (action) {
      _BackupAction.import => OutlinedButton(
        onPressed: onPressed,
        style: _outlinedBackupButtonStyle(action),
        child: Text(_backupButtonLabel(action)),
      ),
      _BackupAction.export => FilledButton(
        onPressed: onPressed,
        style: _filledBackupButtonStyle(action),
        child: Text(_backupButtonLabel(action)),
      ),
    };
  }

  ButtonStyle? _outlinedBackupButtonStyle(_BackupAction action) {
    final color = _backupStatusColor(action);
    if (color == null) return null;

    return OutlinedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      side: BorderSide(color: color),
    );
  }

  ButtonStyle? _filledBackupButtonStyle(_BackupAction action) {
    final color = _backupStatusColor(action);
    if (color == null) return null;

    return FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
    );
  }

  Color? _backupStatusColor(_BackupAction action) {
    if (_backupStatusAction != action) return null;

    return switch (_backupStatus) {
      _BackupActionStatus.success => _connectionSuccessColor,
      _BackupActionStatus.failure => _connectionFailureColor,
      _BackupActionStatus.canceled => const Color(0xff64748b),
      _ => null,
    };
  }

  String _backupButtonLabel(_BackupAction action) {
    if (_backupStatusAction != action ||
        _backupStatus == _BackupActionStatus.idle) {
      return _backupIdleLabel(action);
    }

    return switch (_backupStatus) {
      _BackupActionStatus.running =>
        action == _BackupAction.export ? '导出中...' : '恢复中...',
      _BackupActionStatus.success =>
        action == _BackupAction.export ? '导出成功' : '恢复成功',
      _BackupActionStatus.failure =>
        action == _BackupAction.export ? '导出失败' : '恢复失败',
      _BackupActionStatus.canceled => '已取消',
      _BackupActionStatus.idle => _backupIdleLabel(action),
    };
  }

  String _backupIdleLabel(_BackupAction action) {
    return switch (action) {
      _BackupAction.import => '从备份恢复',
      _BackupAction.export => '导出加密备份',
    };
  }

  _BackupActionStatus _backupStatusForMessage(String message) {
    if (message.contains('取消')) return _BackupActionStatus.canceled;
    if (message.contains('失败') ||
        message.startsWith('没有') ||
        message.startsWith('请先')) {
      return _BackupActionStatus.failure;
    }
    return _BackupActionStatus.success;
  }

  void _scheduleBackupStatusReset() {
    final action = _backupStatusAction;
    _backupStatusResetTimer?.cancel();
    _backupStatusResetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _backupStatusAction != action) return;
      setState(() {
        _backupStatus = _BackupActionStatus.idle;
        _backupStatusAction = null;
      });
    });
  }

  Future<void> _test() async {
    _testStatusResetTimer?.cancel();
    setState(() {
      _testingWebDav = true;
      _testStatus = _ConnectionTestStatus.testing;
    });
    final message = await widget
        .onTestWebDav(_url.text, _account.text, _password.text)
        .catchError((_) => '连接失败');
    if (mounted) {
      setState(() {
        _testStatus = message == '连接成功'
            ? _ConnectionTestStatus.success
            : _ConnectionTestStatus.failure;
        _testingWebDav = false;
      });
      _scheduleTestStatusReset();
    }
  }

  Future<void> _save() async {
    _testStatusResetTimer?.cancel();
    _saveStatusResetTimer?.cancel();
    setState(() {
      _savingWebDav = true;
      _testStatus = _ConnectionTestStatus.idle;
      _saveStatus = _SaveSettingsStatus.saving;
    });
    try {
      await widget.onSaveWebDav(_url.text, _account.text, _password.text);
      if (!mounted) return;
      setState(() {
        _saveStatus = _SaveSettingsStatus.success;
        _savingWebDav = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveStatus = _SaveSettingsStatus.failure;
        _savingWebDav = false;
      });
    }
    _scheduleSaveStatusReset();
  }

  Widget _testConnectionButton() {
    return OutlinedButton(
      onPressed: _testingWebDav || _savingWebDav ? null : _test,
      style: _testConnectionButtonStyle(),
      child: Text(_testConnectionButtonLabel),
    );
  }

  ButtonStyle? _testConnectionButtonStyle() {
    final Color? color = switch (_testStatus) {
      _ConnectionTestStatus.success => _connectionSuccessColor,
      _ConnectionTestStatus.failure => _connectionFailureColor,
      _ => null,
    };

    if (color == null) return null;

    return OutlinedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      side: BorderSide(color: color),
    );
  }

  String get _testConnectionButtonLabel {
    return switch (_testStatus) {
      _ConnectionTestStatus.testing => '测试中...',
      _ConnectionTestStatus.success => '连接成功',
      _ConnectionTestStatus.failure => '连接失败',
      _ConnectionTestStatus.idle => '测试连接',
    };
  }

  Widget _saveSettingsButton() {
    return FilledButton(
      onPressed: _savingWebDav ? null : _save,
      style: _saveSettingsButtonStyle(),
      child: Text(_saveSettingsButtonLabel),
    );
  }

  ButtonStyle? _saveSettingsButtonStyle() {
    final Color? color = switch (_saveStatus) {
      _SaveSettingsStatus.success => _connectionSuccessColor,
      _SaveSettingsStatus.failure => _connectionFailureColor,
      _ => null,
    };

    if (color == null) return null;

    return FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
    );
  }

  String get _saveSettingsButtonLabel {
    return switch (_saveStatus) {
      _SaveSettingsStatus.saving => '保存中...',
      _SaveSettingsStatus.success => '已保存',
      _SaveSettingsStatus.failure => '保存失败',
      _SaveSettingsStatus.idle => '保存设置',
    };
  }

  void _scheduleSaveStatusReset() {
    _saveStatusResetTimer?.cancel();
    _saveStatusResetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _saveStatus = _SaveSettingsStatus.idle);
    });
  }

  void _scheduleTestStatusReset() {
    _testStatusResetTimer?.cancel();
    _testStatusResetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _testStatus = _ConnectionTestStatus.idle);
    });
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
      onSelectionChanged: (selected) {
        final value = selected.first;
        setState(() => _autoLockMinutes = value);
        _savePreferences();
      },
    );
  }

  Widget _strongPasswordRulesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '强密码生成规则',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _compactPreferenceRow(
            title: '密码长度',
            subtitle: '生成新密码时使用',
            trailing: _strongPasswordLengthSelector(context),
          ),
          const SizedBox(height: 12),
          _strongPasswordOptionRow(
            label: '包含字符',
            children: [
              _strongPasswordCheckbox(
                title: '大写字母',
                value: _strongPasswordRules.includeUppercase,
                nextRules: (value) =>
                    _strongPasswordRules.copyWith(includeUppercase: value),
              ),
              _strongPasswordCheckbox(
                title: '小写字母',
                value: _strongPasswordRules.includeLowercase,
                nextRules: (value) =>
                    _strongPasswordRules.copyWith(includeLowercase: value),
              ),
              _strongPasswordCheckbox(
                title: '数字',
                value: _strongPasswordRules.includeDigits,
                nextRules: (value) =>
                    _strongPasswordRules.copyWith(includeDigits: value),
              ),
              _strongPasswordCheckbox(
                title: '符号',
                value: _strongPasswordRules.includeSymbols,
                nextRules: (value) =>
                    _strongPasswordRules.copyWith(includeSymbols: value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _strongPasswordOptionRow(
            label: '其他',
            children: [
              _strongPasswordCheckbox(
                title: '排除易混淆字符',
                value: _strongPasswordRules.excludeAmbiguous,
                nextRules: (value) =>
                    _strongPasswordRules.copyWith(excludeAmbiguous: value),
                isCharacterGroup: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _strongPasswordLengthSelector(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10),
        ),
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      segments: StrongPasswordRules.lengthOptions
          .map(
            (length) =>
                ButtonSegment<int>(value: length, label: Text('$length 位')),
          )
          .toList(),
      selected: {_strongPasswordRules.length},
      onSelectionChanged: (selected) {
        _updateStrongPasswordRules(
          _strongPasswordRules.copyWith(length: selected.first),
        );
      },
    );
  }

  Widget _strongPasswordCheckbox({
    required String title,
    required bool value,
    required StrongPasswordRules Function(bool value) nextRules,
    bool isCharacterGroup = true,
  }) {
    final enabled =
        !isCharacterGroup || !value || _enabledCharacterGroupCount > 1;
    return _StrongPasswordOption(
      label: title,
      value: value,
      enabled: enabled,
      onChanged: (checked) => _updateStrongPasswordRules(nextRules(checked)),
    );
  }

  Widget _strongPasswordOptionRow({
    required String label,
    required List<Widget> children,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xff475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: children)),
      ],
    );
  }

  int get _enabledCharacterGroupCount {
    return [
      _strongPasswordRules.includeUppercase,
      _strongPasswordRules.includeLowercase,
      _strongPasswordRules.includeDigits,
      _strongPasswordRules.includeSymbols,
    ].where((enabled) => enabled).length;
  }

  void _updateStrongPasswordRules(StrongPasswordRules rules) {
    setState(() => _strongPasswordRules = rules.normalized());
    _savePreferences();
  }
}

class _StrongPasswordOption extends StatelessWidget {
  const _StrongPasswordOption({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? const Color(0xff0f172a)
        : const Color(0xff94a3b8);
    final border = value ? const Color(0xff2563eb) : const Color(0xffcbd5e1);
    final background = value ? const Color(0xffeff6ff) : Colors.white;

    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 36,
        padding: const EdgeInsets.only(left: 8, right: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              onChanged: enabled
                  ? (checked) => onChanged(checked ?? false)
                  : null,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: foreground)),
          ],
        ),
      ),
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

const _connectionSuccessColor = Color(0xff079455);
const _connectionFailureColor = Color(0xffdc2626);

enum _ConnectionTestStatus { idle, testing, success, failure }

enum _SaveSettingsStatus { idle, saving, success, failure }

enum _BackupAction { export, import }

enum _BackupActionStatus { idle, running, success, failure, canceled }
