import 'package:flutter/material.dart';

import '../../core/models/vault_entry.dart';

class RecycleBinScreen extends StatelessWidget {
  const RecycleBinScreen({
    super.key,
    required this.entries,
    required this.onRestore,
    required this.onDeleteForever,
    required this.onBack,
  });

  final List<VaultEntry> entries;
  final ValueChanged<String> onRestore;
  final ValueChanged<String> onDeleteForever;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(title: '回收站', onBack: onBack),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('回收站为空'))
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Card(
                      child: ListTile(
                        title: Text(entry.title),
                        subtitle: Text(entry.account),
                        trailing: Wrap(
                          children: [
                            TextButton(
                              onPressed: () => onRestore(entry.id),
                              child: const Text('恢复'),
                            ),
                            TextButton(
                              onPressed: () => _confirmDelete(context, entry),
                              child: const Text('永久删除'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, VaultEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('永久删除“${entry.title}”？'),
        content: const Text('永久删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (ok == true) onDeleteForever(entry.id);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

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
      ],
    );
  }
}
