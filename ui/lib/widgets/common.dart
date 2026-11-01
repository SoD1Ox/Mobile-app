/// Shared UI building blocks used across every screen so the app stays
/// in one visual style (glass Material 3, same paddings, same error handling).
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:ui' as ui show ImageFilter;

import '../app_state.dart';
import '../theme/glass.dart' show kGlassRadius;
import 'glass_icons.dart';

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
  final T? value;
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
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          dropdownColor: const Color(0xF210302B),
          style: const TextStyle(color: Colors.white),
          menuMaxHeight: 360,
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

/// Hiring-pipeline stage colors (application statuses).
Color statusColor(String s) => switch (s) {
      'new' => const Color(0xFF9DB4AE),
      'review' => const Color(0xFF5BC8E8),
      'interview' => const Color(0xFFFFB35C),
      'offer' => const Color(0xFFFF8A66),
      'hired' => const Color(0xFF3ED9B8),
      'rejected' => const Color(0xFFF16A6A),
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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF16A6A)),
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

/// Frosted-glass list card.  On native platforms it is REAL glass: one
/// BackdropFilter gaussian blur behind a translucent gradient + hairline
/// border.  On web (CanvasKit) live blur inside long scrolling lists costs a
/// full-surface re-rasterization per frame, so there we keep the identical
/// cheap gradient-frost paint instead — visually indistinguishable over the
/// static aurora backdrop.
class GlassListCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const GlassListCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final inner = _glassDecorated(child: child, onTap: onTap);
    if (kIsWeb) return inner;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ClipRRect(
        borderRadius: kGlassRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: inner,
        ),
      ),
    );
  }
}

/// Shared frosted decoration used by [GlassListCard] (and web fallback).
Widget _glassDecorated({required Widget child, VoidCallback? onTap}) =>
    DecoratedBox(
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
    );

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
