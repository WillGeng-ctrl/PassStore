import 'package:flutter/material.dart';

import 'form_error_slot.dart';

class CreateVaultScreen extends StatefulWidget {
  const CreateVaultScreen({super.key, required this.onCreate});

  final Future<void> Function(String masterPassword) onCreate;

  @override
  State<CreateVaultScreen> createState() => _CreateVaultScreenState();
}

class _CreateVaultScreenState extends State<CreateVaultScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f6f8),
      body: Center(
        child: SizedBox(
          width: 520,
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'Logo/LogoA_256.png',
                      width: 72,
                      height: 72,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'PassStore',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('创建你的密码库', textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '主密码',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '确认主密码',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xfffff7df),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      border: Border.fromBorderSide(
                        BorderSide(color: Color(0xffffd666)),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('重要：主密码无法找回，请务必牢记。忘记主密码将无法访问密码库中的任何数据。'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FormErrorSlot(message: _error),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? '创建中...' : '创建密码库'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final password = _password.text;
    if (password.length < 8) {
      setState(() => _error = '主密码至少需要 8 位');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = '两次输入的主密码不一致');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onCreate(password);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
