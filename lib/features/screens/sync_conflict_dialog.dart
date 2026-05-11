import 'package:flutter/material.dart';

import '../../core/services/vault_merge.dart';
import 'passstore_dialog.dart';

class SyncConflictDialog extends StatelessWidget {
  const SyncConflictDialog({super.key, required this.conflict});

  final FieldConflict conflict;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const PassStoreDialogTitle('解决同步冲突'),
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
      actionsPadding: EdgeInsets.zero,
      actions: [
        PassStoreDialogActions(
          primaryLabel: '选择云端值',
          secondaryLabel: '选择本机值',
          onPrimary: () => Navigator.pop(context, ConflictChoice.remote),
          onCancel: () => Navigator.pop(context, ConflictChoice.local),
        ),
      ],
    );
  }

  Widget _valueTile(String title, Object? value) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xfff8fafc),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: Text('${value ?? ''}')),
          ],
        ),
      ),
    );
  }
}

enum ConflictChoice { local, remote }
