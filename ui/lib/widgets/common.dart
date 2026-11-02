/// Shared UI building blocks used across every screen so the app stays
/// in one visual style (glass Material 3, same paddings, same error handling).
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/glass.dart' show kGlassRadius;
import '../models/models.dart';
import 'glass_icons.dart';

/// Theme-aware foreground color for secondary labels and helper text.
Color appTextColor(BuildContext context, {double opacity = 1}) =>
    Theme.of(context).colorScheme.onSurface.withOpacity(opacity);

/// Standard form text field with validation message shown inline.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Widget? suffix;
  final int maxLines;
  final TextInputType? keyboardType;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
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
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
              labelText: label, hintText: hint, suffixIcon: suffix),
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
          dropdownColor: Theme.of(context).colorScheme.surface,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          menuMaxHeight: 320,
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
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена')),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF16A6A)),
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

/// Frosted-glass list card. It uses a tinted gradient and a defined outline,
/// never a live blur, so scrolling stays smooth on mid-range phones.
class GlassListCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassListCard(
      {super.key, required this.child, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: _glassDecorated(
        context,
        child: child,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

/// Shared frosted decoration used by [GlassListCard] (and web fallback).
Widget _glassDecorated(BuildContext context,
        {required Widget child,
        VoidCallback? onTap,
        VoidCallback? onLongPress}) =>
    DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: kGlassRadius,
        gradient: Theme.of(context).brightness == Brightness.dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF202F2B), Color(0xFF1B2925)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFEFDF9), Color(0xFFF7F7F1)],
              ),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF3D5049)
              : const Color(0xFFDDE3D9),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
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
      {super.key,
      required this.page,
      required this.pages,
      required this.onChanged});

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
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.72))),
          GlassIconButton(Glyph.chevronRight,
              onPressed: page < pages ? () => onChanged(page + 1) : null),
        ],
      ),
    );
  }
}

/// Animated horizontal funnel bars: per-stage counts of applications.
class FunnelBars extends StatelessWidget {
  final Map<String, int> counts;
  const FunnelBars({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final max = counts.values.fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final stage in ApplicationItem.pipelineOrder)
          if (counts.containsKey(stage))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(ApplicationItem.statusLabels[stage]!,
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: counts[stage]! / max),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, f, _) => Stack(
                          children: [
                            Container(
                                height: 18,
                                color: Colors.white.withOpacity(0.06)),
                            FractionallySizedBox(
                              widthFactor: f.clamp(0.03, 1.0),
                              child: Container(
                                height: 18,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    statusColor(stage).withOpacity(0.85),
                                    statusColor(stage).withOpacity(0.45),
                                  ]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text('${counts[stage]}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
