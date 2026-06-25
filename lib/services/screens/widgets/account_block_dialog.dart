import 'package:flutter/material.dart';

Future<String?> showAccountBlockDialog(
  BuildContext context, {
  required String targetName,
}) async {
  final detailController = TextEditingController();
  final result = await showDialog<String?>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Block $targetName?'),
      content: TextField(
        controller: detailController,
        decoration: const InputDecoration(
          labelText: 'Short reason (required)',
          hintText: 'e.g. Policy violation',
        ),
        maxLines: 2,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (detailController.text.trim().isEmpty) return;
            Navigator.pop(ctx, detailController.text.trim());
          },
          child: const Text('Block', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  detailController.dispose();
  return result;
}
