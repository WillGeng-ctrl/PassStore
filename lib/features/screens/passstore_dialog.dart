import 'package:flutter/material.dart';

class PassStoreDialogTitle extends StatelessWidget {
  const PassStoreDialogTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: const Color(0xff0f172a),
      ),
    );
  }
}

class PassStoreDialogActions extends StatelessWidget {
  const PassStoreDialogActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onCancel,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: onPrimary,
              child: Text(primaryLabel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(onPressed: onCancel, child: const Text('取消')),
          ),
        ],
      ),
    );
  }
}
