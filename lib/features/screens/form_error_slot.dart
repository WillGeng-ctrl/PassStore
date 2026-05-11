import 'package:flutter/material.dart';

class FormErrorSlot extends StatelessWidget {
  const FormErrorSlot({super.key, required this.message, this.height = 36});

  final String? message;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = message;
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: text == null
            ? const SizedBox.shrink()
            : Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}
