import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/category.dart';
import '../../core/models/strong_password_rules.dart';
import '../../core/models/vault_entry.dart';
import '../../core/services/strong_password_generator.dart';
import 'passstore_dialog.dart';

class EditEntryDialog extends StatefulWidget {
  const EditEntryDialog({
    super.key,
    required this.categories,
    required this.initialCategoryId,
    this.entry,
    this.clipboardClearSeconds = 30,
    this.strongPasswordRules = StrongPasswordRules.defaults,
  });

  final List<Category> categories;
  final String initialCategoryId;
  final VaultEntry? entry;
  final int clipboardClearSeconds;
  final StrongPasswordRules strongPasswordRules;

  @override
  State<EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<EditEntryDialog> {
  late final TextEditingController _title;
  late final TextEditingController _account;
  late final TextEditingController _password;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  late String _categoryId;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _title = TextEditingController(text: entry?.title ?? '');
    _account = TextEditingController(text: entry?.account ?? '');
    _password = TextEditingController(text: entry?.password ?? '');
    _url = TextEditingController(text: entry?.url ?? '');
    _notes = TextEditingController(text: entry?.notes ?? '');
    _categoryId = entry?.categoryId ?? widget.initialCategoryId;
  }

  @override
  void dispose() {
    _title.dispose();
    _account.dispose();
    _password.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: PassStoreDialogTitle(widget.entry == null ? '新建条目' : '编辑条目'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _categorySelector(context),
              const SizedBox(height: 12),
              _copyField(controller: _account, label: '账号'),
              const SizedBox(height: 12),
              _copyField(
                controller: _password,
                label: '密码',
                trailing: IconButton(
                  tooltip: '生成强密码',
                  icon: const Icon(Icons.auto_awesome),
                  onPressed: _generatePassword,
                ),
              ),
              const SizedBox(height: 12),
              _copyField(controller: _url, label: '网址'),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '备注',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: EdgeInsets.zero,
      actions: [
        PassStoreDialogActions(
          primaryLabel: '保存',
          onPrimary: _save,
          onCancel: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _categorySelector(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '分类',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.fromLTRB(12, 14, 12, 10),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.categories.map((category) {
          return ChoiceChip(
            label: Text(category.name),
            selected: _categoryId == category.id,
            onSelected: (_) => setState(() => _categoryId = category.id),
          );
        }).toList(),
      ),
    );
  }

  Widget _copyField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    Widget? trailing,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?trailing,
            IconButton(
              tooltip: '复制$label',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () {
                final copiedText = controller.text;
                Clipboard.setData(ClipboardData(text: copiedText));
                _scheduleClipboardClear(copiedText);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(_copyMessage(label))));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleClipboardClear(String copiedText) {
    final seconds = widget.clipboardClearSeconds;
    if (seconds <= 0 || copiedText.isEmpty) return;
    Timer(Duration(seconds: seconds), () async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == copiedText) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  String _copyMessage(String label) {
    final seconds = widget.clipboardClearSeconds;
    if (seconds <= 0) return '$label已复制';
    return '$label已复制，${_formatClipboardDelay(seconds)}后自动清空剪贴板';
  }

  String _formatClipboardDelay(int seconds) {
    if (seconds >= 60 && seconds % 60 == 0) return '${seconds ~/ 60}分钟';
    return '$seconds秒';
  }

  Future<void> _generatePassword() async {
    if (_password.text.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const PassStoreDialogTitle('替换当前密码？'),
            content: const Text('生成强密码会覆盖当前密码。'),
            actionsPadding: EdgeInsets.zero,
            actions: [
              PassStoreDialogActions(
                primaryLabel: '替换',
                onPrimary: () => Navigator.pop(context, true),
                onCancel: () => Navigator.pop(context, false),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    setState(() {
      _password.text = StrongPasswordGenerator.generate(
        widget.strongPasswordRules,
      );
    });
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      EntryDraft(
        title: _title.text.trim(),
        account: _account.text.trim(),
        password: _password.text,
        url: _url.text.trim(),
        notes: _notes.text.trim(),
        categoryId: _categoryId,
      ),
    );
  }
}

class EntryDraft {
  const EntryDraft({
    required this.title,
    required this.account,
    required this.password,
    required this.url,
    required this.notes,
    required this.categoryId,
  });

  final String title;
  final String account;
  final String password;
  final String url;
  final String notes;
  final String categoryId;
}
