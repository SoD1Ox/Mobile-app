/// Shared UI building blocks used across every screen so the app stays
/// in one visual style (Material 3, same paddings, same error handling).
library;

import 'package:flutter/material.dart';

import '../app_state.dart';

/// Standard form text field with validation message shown inline.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Widget? suffix;
  final int maxLines;
  final TextInputType? keyboardType;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.obscureText = false,
    this.suffix,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: suffix,
          ),
        ),
      );
}

/// Colored chip for task status / priority.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

Color statusColor(String s) => switch (s) {
      'new' => Colors.blueGrey,
      'in_progress' => Colors.blue,
      'review' => Colors.deepPurple,
      'done' => Colors.green,
      'canceled' => Colors.red,
      _ => Colors.grey,
    };

Color priorityColor(String p) => switch (p) {
      'low' => Colors.green,
      'medium' => Colors.orange,
      'high' => Colors.deepOrange,
      'critical' => Colors.red,
      _ => Colors.grey,
    };

/// Confirmation dialog returning true/false — used before destructive actions.
Future<bool> confirmDialog(BuildContext context, String title, String text,
    {String okLabel = 'Удалить'}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okLabel)),
      ],
    ),
  );
  return res ?? false;
}

/// Wraps a Future and shows an error SnackBar if it throws.
/// Returns true when the action succeeded.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action,
    {VoidCallback? onFinally}) async {
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  } finally {
    onFinally?.call();
  }
}

/// Simple centered loader used while fetching data.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
