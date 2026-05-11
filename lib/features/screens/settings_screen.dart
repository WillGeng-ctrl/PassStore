import 'package:flutter/material.dart';

import '../../data/webdav_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.initialSettings,
    required this.onSaveWebDav,
    required this.onTestWebDav,
    required this.onChangeMasterPassword,
    required this.onBack,
  });

  final WebDavSettings initialSettings;
  final Future<void> Function(String url, String account, String appPassword)
  onSaveWebDav;
  final Future<String> Function(String url, String account, String appPassword)
  onTestWebDav;
  final Future<void> Function() onChangeMasterPassword;
  final VoidCallback onBack;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;
  late final TextEditingController _account;
  final _password = TextEditingController();
  String _testMessage = '';
  String _saveMessage = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.initialSettings.url);
    _account = TextEditingController(text: widget.initialSettings.account);
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
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('自动锁定时间'),
                  subtitle: Text('15 分钟'),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('剪贴板清空时间'),
                  subtitle: Text('30 秒'),
                ),
              ]),
              _group('备份与恢复', const [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('导出加密备份'),
                  subtitle: Text('保存当前加密 vault 文件副本'),
                ),
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
}
