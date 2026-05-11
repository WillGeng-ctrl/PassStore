import 'package:flutter/material.dart';

class ChangeMasterPasswordDialog extends StatefulWidget {
  const ChangeMasterPasswordDialog({super.key});

  @override
  State<ChangeMasterPasswordDialog> createState() => _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState extends State<ChangeMasterPasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改主密码'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: '当前主密码', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _next, obscureText: true, decoration: const InputDecoration(labelText: '新主密码', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: '确认新主密码', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const Text('修改主密码会重新加密本地密码库，请确保修改前已完成同步或备份。'),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('确认修改')),
      ],
    );
  }

  void _submit() {
    if (_next.text.length < 8) {
      setState(() => _error = '新主密码至少需要 8 位');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = '两次输入的新主密码不一致');
      return;
    }
    Navigator.pop(context, ChangeMasterPasswordDraft(current: _current.text, next: _next.text));
  }
}

class ChangeMasterPasswordDraft {
  const ChangeMasterPasswordDraft({required this.current, required this.next});

  final String current;
  final String next;
}
