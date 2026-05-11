import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/category.dart';
import '../../core/models/vault_entry.dart';

class EditEntryDialog extends StatefulWidget {
  const EditEntryDialog({
    super.key,
    required this.categories,
    required this.initialCategoryId,
    this.entry,
  });

  final List<Category> categories;
  final String initialCategoryId;
  final VaultEntry? entry;

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
      title: Text(widget.entry == null ? '新建条目' : '编辑条目'),
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
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: '分类',
                  border: OutlineInputBorder(),
                ),
                items: widget.categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _categoryId = value ?? _categoryId),
              ),
              const SizedBox(height: 12),
              _copyField(controller: _account, label: '账号'),
              const SizedBox(height: 12),
              _copyField(controller: _password, label: '密码'),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
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
                Clipboard.setData(ClipboardData(text: controller.text));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$label已复制，稍后自动清空剪贴板')));
              },
            ),
          ],
        ),
      ),
    );
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
