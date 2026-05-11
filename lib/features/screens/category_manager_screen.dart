import 'package:flutter/material.dart';

import '../../core/models/category.dart';

class CategoryManagerScreen extends StatelessWidget {
  const CategoryManagerScreen({
    super.key,
    required this.categories,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
    required this.onBack,
  });

  final List<Category> categories;
  final ValueChanged<String> onAdd;
  final void Function(String categoryId, String name) onRename;
  final ValueChanged<String> onDelete;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final builtIns = categories
        .where((category) => category.isBuiltIn)
        .toList();
    final customs = categories
        .where((category) => !category.isBuiltIn)
        .toList();
    return _SettingsLikePage(
      title: '管理分类',
      onBack: onBack,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _section('默认分类'),
          ...builtIns.map((category) => _row(context, category, locked: true)),
          const SizedBox(height: 24),
          _customSectionHeader(context),
          if (customs.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('还没有自定义分类')),
          ...customs.map((category) => _row(context, category)),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );

  Widget _customSectionHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          const Text(
            '自定义分类',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _askAdd(context),
            icon: const Icon(Icons.add),
            label: const Text('新建自定义分类'),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Category category, {bool locked = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(locked ? Icons.lock_outline : Icons.folder_outlined),
        title: Text(category.name),
        subtitle: Text(locked ? '默认分类，无法编辑' : '自定义分类'),
        trailing: locked
            ? const Text('无法编辑')
            : Wrap(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _askRename(context, category),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, category),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _askAdd(BuildContext context) async {
    final value = await _nameDialog(context, '新建分类', '');
    if (value != null && value.trim().isNotEmpty) onAdd(value.trim());
  }

  Future<void> _askRename(BuildContext context, Category category) async {
    final value = await _nameDialog(context, '重命名分类', category.name);
    if (value != null && value.trim().isNotEmpty) {
      onRename(category.id, value.trim());
    }
  }

  Future<void> _confirmDelete(BuildContext context, Category category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除“${category.name}”？'),
        content: const Text('该分类下的条目会移动到“其他”。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) onDelete(category.id);
  }

  Future<String?> _nameDialog(
    BuildContext context,
    String title,
    String initial,
  ) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) {
        void submit() => Navigator.pop(context, controller.text);

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => submit(),
            decoration: const InputDecoration(labelText: '分类名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(onPressed: submit, child: const Text('保存')),
          ],
        );
      },
    );
  }
}

class _SettingsLikePage extends StatelessWidget {
  const _SettingsLikePage({
    required this.title,
    required this.child,
    required this.onBack,
  });

  final String title;
  final Widget child;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          elevation: 0,
          color: Colors.white,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 20),
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}
