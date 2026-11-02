import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/glass_stack.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final user = scope.user!;
    return Scaffold(
      appBar: AppBar(
        leading: GlassIconButton(
          Glyph.back,
          tooltip: 'Назад',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Внешний вид', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text('Выберите комфортную тему приложения.',
              style: TextStyle(color: appTextColor(context, opacity: .7))),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: scope.theme,
            builder: (context, _) => Row(
              children: [
                _ThemeChoice(
                  label: 'Тёмная',
                  glyph: Glyph.eyeOff,
                  selected: scope.theme.value == ThemeMode.dark,
                  onTap: () => scope.theme.setMode(ThemeMode.dark),
                ),
                const SizedBox(width: 8),
                _ThemeChoice(
                  label: 'Светлая',
                  glyph: Glyph.eye,
                  selected: scope.theme.value == ThemeMode.light,
                  onTap: () => scope.theme.setMode(ThemeMode.light),
                ),
                const SizedBox(width: 8),
                _ThemeChoice(
                  label: 'Системная',
                  glyph: Glyph.dashboard,
                  selected: scope.theme.value == ThemeMode.system,
                  onTap: () => scope.theme.setMode(ThemeMode.system),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Уведомления', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          RealGlassCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: ListenableBuilder(
              listenable: scope.notifications,
              builder: (context, _) => SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const GlassIcon(Glyph.bell, size: 22),
                title: const Text('События приложения'),
                subtitle: const Text('Сохранение вакансий и изменения записей'),
                value: scope.notifications.enabled,
                onChanged: scope.notifications.setEnabled,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('Аккаунт', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          RealGlassCard(
            margin: EdgeInsets.zero,
            child: Row(
              children: [
                const GlassIcon(Glyph.person, size: 25),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text('@${user.username} · ${user.roleLabel}',
                          style: TextStyle(
                              color: appTextColor(context, opacity: .72))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final String label;
  final Glyph glyph;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChoice({
    required this.label,
    required this.glyph,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary.withOpacity(.17)
                    : Theme.of(context).colorScheme.surface.withOpacity(.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
                ),
              ),
              child: Column(
                children: [
                  GlassIcon(glyph,
                      size: 22,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  const SizedBox(height: 7),
                  FittedBox(child: Text(label)),
                ],
              ),
            ),
          ),
        ),
      );
}
