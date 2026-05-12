import 'package:flutter/material.dart';

import '../../core/models/category.dart';
import '../../core/models/vault.dart';
import '../../core/models/vault_entry.dart';

class MainVaultScreen extends StatefulWidget {
  const MainVaultScreen({
    super.key,
    required this.vault,
    required this.onNewEntry,
    required this.onEditEntry,
    required this.onDeleteEntry,
    required this.onOpenSettings,
    required this.onOpenCategories,
    required this.onOpenRecycleBin,
    required this.onLock,
    required this.syncStatus,
    this.onSync,
  });

  final Vault vault;
  final ValueChanged<String> onNewEntry;
  final ValueChanged<VaultEntry> onEditEntry;
  final ValueChanged<String> onDeleteEntry;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenRecycleBin;
  final VoidCallback onLock;
  final String syncStatus;
  final Future<void> Function()? onSync;

  @override
  State<MainVaultScreen> createState() => _MainVaultScreenState();
}

class _MainVaultScreenState extends State<MainVaultScreen> {
  String? _selectedCategoryId;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final activeEntries = widget.vault.entries
        .where((entry) => !entry.isDeleted)
        .toList();
    final filtered = activeEntries.where((entry) {
      if (_selectedCategoryId != null &&
          entry.categoryId != _selectedCategoryId) {
        return false;
      }
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      return '${entry.title} ${entry.account} ${entry.url}'
          .toLowerCase()
          .contains(query);
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final selectedCategoryName = _selectedCategoryId == null
        ? '全部'
        : widget.vault.categories
              .firstWhere((category) => category.id == _selectedCategoryId)
              .name;

    return Scaffold(
      body: Column(
        children: [
          _TopBar(
            syncStatus: widget.syncStatus,
            onSync: widget.onSync,
            onSettings: widget.onOpenSettings,
            onLock: widget.onLock,
          ),
          Expanded(
            child: Row(
              children: [
                _CategoryTree(
                  categories: widget.vault.categories,
                  selectedCategoryId: _selectedCategoryId,
                  onSelectAll: () => setState(() => _selectedCategoryId = null),
                  onSelectCategory: (id) =>
                      setState(() => _selectedCategoryId = id),
                  onNewEntry: () => widget.onNewEntry(
                    _selectedCategoryId ?? Category.websiteId,
                  ),
                  onOpenCategories: widget.onOpenCategories,
                  onOpenRecycleBin: widget.onOpenRecycleBin,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: '搜索...',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) =>
                                    setState(() => _query = value),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Text(
                              selectedCategoryName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${filtered.length} 个条目',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('没有条目'))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  20,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final entry = filtered[index];
                                  final category = widget.vault.categories
                                      .firstWhere(
                                        (item) => item.id == entry.categoryId,
                                      );
                                  return ListTile(
                                    title: Text(entry.title),
                                    subtitle: Text(
                                      '${entry.account}  ·  ${entry.url}',
                                    ),
                                    leading: Icon(categoryIcon(category)),
                                    trailing: Wrap(
                                      spacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          _dateText(entry.updatedAt),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        IconButton(
                                          tooltip: '编辑',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () =>
                                              widget.onEditEntry(entry),
                                        ),
                                        IconButton(
                                          tooltip: '删除',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () =>
                                              widget.onDeleteEntry(entry.id),
                                        ),
                                      ],
                                    ),
                                    onTap: () => widget.onEditEntry(entry),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateText(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.syncStatus,
    required this.onSync,
    required this.onSettings,
    required this.onLock,
  });

  final String syncStatus;
  final Future<void> Function()? onSync;
  final VoidCallback onSettings;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            const SizedBox(width: 20),
            const Text(
              'PassStore',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 16),
            _SyncBadge(label: syncStatus, onTap: onSync),
            const Spacer(),
            IconButton(
              tooltip: '设置',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
            IconButton(
              tooltip: '锁定',
              onPressed: onLock,
              icon: const Icon(Icons.lock_outline),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}

class _CategoryTree extends StatefulWidget {
  const _CategoryTree({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectAll,
    required this.onSelectCategory,
    required this.onNewEntry,
    required this.onOpenCategories,
    required this.onOpenRecycleBin,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final VoidCallback onSelectAll;
  final ValueChanged<String> onSelectCategory;
  final VoidCallback onNewEntry;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenRecycleBin;

  @override
  State<_CategoryTree> createState() => _CategoryTreeState();
}

class _CategoryTreeState extends State<_CategoryTree> {
  bool _categoryExpanded = true;
  bool _customExpanded = true;

  @override
  Widget build(BuildContext context) {
    final builtIns = widget.categories
        .where((category) => category.isBuiltIn)
        .toList();
    final customs = widget.categories
        .where((category) => !category.isBuiltIn)
        .toList();
    return Container(
      width: 248,
      color: const Color(0xfff8fafc),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: FilledButton.icon(
              onPressed: widget.onNewEntry,
              icon: const Icon(Icons.add),
              label: const Text('新建条目'),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _treeItem(
                  icon: Icons.inventory_2_outlined,
                  label: '全部',
                  selected: widget.selectedCategoryId == null,
                  onTap: widget.onSelectAll,
                ),
                _treeHeader(
                  '分类',
                  _categoryExpanded,
                  () => setState(() => _categoryExpanded = !_categoryExpanded),
                ),
                if (_categoryExpanded)
                  ...builtIns.map(
                    (category) => _categoryItem(category, depth: 1),
                  ),
                _treeHeader(
                  '自定义分类',
                  _customExpanded,
                  () => setState(() => _customExpanded = !_customExpanded),
                ),
                if (_customExpanded)
                  if (customs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(44, 8, 16, 8),
                      child: Text('暂无自定义分类'),
                    )
                  else
                    ...customs.map(
                      (category) => _categoryItem(category, depth: 1),
                    ),
              ],
            ),
          ),
          const Divider(height: 1),
          _treeItem(
            icon: Icons.delete_outline,
            label: '回收站',
            selected: false,
            onTap: widget.onOpenRecycleBin,
          ),
          _treeItem(
            icon: Icons.folder_open_outlined,
            label: '管理分类',
            selected: false,
            onTap: widget.onOpenCategories,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _treeHeader(String label, bool expanded, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: Icon(expanded ? Icons.expand_more : Icons.chevron_right),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      onTap: onTap,
    );
  }

  Widget _categoryItem(Category category, {required int depth}) {
    return _treeItem(
      icon: categoryIcon(category),
      label: category.name,
      selected: widget.selectedCategoryId == category.id,
      onTap: () => widget.onSelectCategory(category.id),
      depth: depth,
    );
  }

  Widget _treeItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int depth = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: 8 + depth * 20, right: 8),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: selected,
        selectedTileColor: const Color(0xffeaf2ff),
        selectedColor: const Color(0xff1d4ed8),
        iconColor: selected ? const Color(0xff1d4ed8) : const Color(0xff334155),
        textColor: selected ? const Color(0xff1d4ed8) : const Color(0xff0f172a),
        leading: Icon(icon),
        title: Text(label),
        onTap: onTap,
      ),
    );
  }
}

IconData categoryIcon(Category category) {
  return switch (category.id) {
    Category.websiteId => Icons.public,
    Category.emailId => Icons.email_outlined,
    Category.appId => Icons.apps_outlined,
    Category.gameId => Icons.sports_esports_outlined,
    Category.otherId => Icons.archive_outlined,
    _ => Icons.folder_outlined,
  };
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.label, this.onTap});

  final String label;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final configured = label == '已同步';
    final background = configured
        ? const Color(0xffecfdf3)
        : const Color(0xfff1f5f9);
    final foreground = configured
        ? const Color(0xff079455)
        : const Color(0xff475569);
    final icon = configured
        ? Icons.check_circle_outline
        : Icons.cloud_off_outlined;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap == null ? null : () => onTap!(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
