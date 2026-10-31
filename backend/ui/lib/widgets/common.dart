/// Shared UI building blocks used across every screen so the app stays
/// in one visual style (glass Material 3, same paddings, same error handling).
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import 'glass_icons.dart';
import '../theme/glass.dart';

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
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: label, suffixIcon: suffix),
        ),
      );
}

/// Glass dropdown that matches [AppTextField] styling.
class AppDropdown<T> extends StatelessWidget {
  final T value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  const AppDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DropdownButtonFormField<T>(
          value: value,
          decoration: InputDecoration(labelText: label),
          dropdownColor: const Color(0xF216294E),
          style: const TextStyle(color: Colors.white),
          items: items,
          onChanged: onChanged,
          validator: validator,
        ),
      );
}

/// Colored glass chip for task status / priority.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.55)),
        ),
        child: Text(label,
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

Color statusColor(String s) => switch (s) {
      'new' => Color(0xFF7986CB),
      'in_progress' => Color(0xFF42A5F5),
      'review' => Color(0xFF9575CD),
      'done' => Color(0xFF66BB6A),
      'canceled' => Color(0xFFEF5350),
      _ => Colors.grey,
    };

Color priorityColor(String p) => switch (p) {
      'low' => Color(0xFF66BB6A),
      'medium' => Color(0xFFFFA726),
      'high' => Color(0xFFFF7043),
      'critical' => Color(0xFFEF5350),
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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF5350)),
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

/// Frosted-glass list card: translucent gradient fill + hairline border.
/// Deliberately NO BackdropFilter inside scrolling lists — blur would be
/// re-rasterized per frame and kill scroll FPS; this paints one cheap layer.
class GlassListCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const GlassListCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: kGlassRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.13),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: kGlassRadius,
              child: child,
            ),
          ),
        ),
      );
}

/// Page indicator shared by paginated screens.
class PagerBar extends StatelessWidget {
  final int page;
  final int pages;
  final ValueChanged<int> onChanged;

  const PagerBar(
      {super.key, required this.page, required this.pages, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (pages <= 1) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassIconButton(Glyph.chevronLeft,
              onPressed: page > 1 ? () => onChanged(page - 1) : null),
          Text('Стр. $page из $pages',
              style: const TextStyle(color: Colors.white70)),
          GlassIconButton(Glyph.chevronRight,
              onPressed: page < pages ? () => onChanged(page + 1) : null),
        ],
      ),
    );
  }
}
