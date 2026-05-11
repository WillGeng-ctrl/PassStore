import 'package:flutter/material.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, required this.onUnlock});

  final Future<void> Function(String masterPassword) onUnlock;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f7f4),
      body: Center(
        child: SizedBox(
          width: 440,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_rounded, size: 52, color: Color(0xff245f52)),
                  const SizedBox(height: 16),
                  Text('PassStore', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 24),
                  TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: '主密码', border: OutlineInputBorder())),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? '解锁中...' : '解锁')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onUnlock(_password.text);
    } catch (_) {
      setState(() => _error = '主密码不正确');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
