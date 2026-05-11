import 'package:flutter/material.dart';

import '../../core/services/vault_merge.dart';

class SyncConflictDialog extends StatelessWidget {
  const SyncConflictDialog({super.key, required this.conflict});

  final FieldConflict conflict;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('解决同步冲突'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('冲突字段：${conflict.fieldName}'),
            const SizedBox(height: 16),
            _valueTile('本机版本', conflict.localValue),
            const SizedBox(height: 8),
            _valueTile('云端版本', conflict.remoteValue),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, ConflictChoice.local), child: const Text('选择本机值')),
        FilledButton(onPressed: () => Navigator.pop(context, ConflictChoice.remote), child: const Text('选择云端值')),
      ],
    );
  }

  Widget _valueTile(String title, Object? value) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xfff4f6f3), borderRadius: BorderRadius.all(Radius.circular(8))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(width: 80, child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text('${value ?? ''}')),
          ],
        ),
      ),
    );
  }
}

enum ConflictChoice { local, remote }
