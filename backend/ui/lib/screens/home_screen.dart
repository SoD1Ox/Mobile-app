/// Authenticated app shell: dashboard + tab navigation (Задачи / Проекты /
/// Клиенты / Пользователи) with an IndexedStack so every tab keeps its state
/// (search text, filters, loaded pages) while switching tabs.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'clients_screen.dart';
import 'projects_screen.dart';
import 'tasks_screen.dart';
import 'users_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _taskCount;
  int? _projectCount;
  int? _clientCount;
  bool _statsLoading = false;

  /// Currently selected bottom-navigation tab.
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    final api = AppScope.of(context).api;
    try {
      final results = await Future.wait([
        api.get('/tasks', {'page_size': 1}),
        api.get('/projects', {'page_size': 1}),
        api.get('/clients', {'page_size': 1}),
      ]);
      if (!mounted) return;
      setState(() {
        _taskCount = results[0]['total'];
        _projectCount = results[1]['total'];
        _clientCount = results[2]['total'];
        _statsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statsLoading = false);
      showError(context, e);
    }
  }

  void _openSection(int index) => setState(() => _tab = index);

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final user = scope.user!;
    final hour = DateTime.now().hour;
    final greeting = hour < 6
        ? 'Доброй ночи'
        : hour < 12
            ? 'Доброе утро'
            : hour < 18
                ? 'Добрый день'
                : 'Добрый вечер';

    // Tab order is fixed; the admin tab is appended only for admins, so the
    // indices of the destinations below must stay in sync with this list.
    final tabs = <Widget>[
      // ==================== Dashboard tab ====================
      _dashboard(user, greeting, scope),
      // ==================== section tabs =====================
      const TasksScreen(),
      const ProjectsScreen(),
      const ClientsScreen(),
      if (user.isAdmin) const UsersScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Главная'),
          const NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Задачи'),
          const NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Проекты'),
          const NavigationDestination(
              icon: Icon(Icons.business_outlined),
              selectedIcon: Icon(Icons.business),
              label: 'Клиенты'),
          if (user.isAdmin)
            const NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Пользователи'),
        ],
      ),
    );
  }

  /// Dashboard tab content (greeting, stats, quick links to the sections).
  Widget _dashboard(AppUser user, String greeting, AppScope scope) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Tracker'),
        actions: [
          IconButton(
              tooltip: 'Выйти',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final yes = await confirmDialog(context, 'Выйти?',
                    'Сессия будет завершена.',
                    okLabel: 'Выйти');
                if (!yes || !context.mounted) return;
                await scope.api.clearTokens();
                scope.onSignedOut();
              }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // -------- greeting card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(user.fullName.characters.first.toUpperCase(),
                          style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$greeting, ${user.fullName}!',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text('@${user.username} · ${user.email}'),
                          const SizedBox(height: 6),
                          StatusChip(
                              label: user.roleLabel,
                              color: user.isAdmin
                                  ? Colors.purple
                                  : user.isManager
                                      ? Colors.blue
                                      : Colors.teal),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // -------- quick stats
            Row(
              children: [
                Expanded(
                    child: _StatTile(
                        icon: Icons.assignment,
                        label: 'Задачи',
                        value: _taskCount,
                        loading: _statsLoading)),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatTile(
                        icon: Icons.folder_outlined,
                        label: 'Проекты',
                        value: _projectCount,
                        loading: _statsLoading)),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatTile(
                        icon: Icons.business_outlined,
                        label: 'Клиенты',
                        value: _clientCount,
                        loading: _statsLoading)),
              ],
            ),
            const SizedBox(height: 16),

            // -------- navigation
            Text('Разделы', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _NavCard(
                icon: Icons.assignment_outlined,
                title: 'Задачи',
                subtitle: 'Поиск, фильтры, пагинация, комментарии',
                onTap: () => _openSection(1)),
            _NavCard(
                icon: Icons.folder_outlined,
                title: 'Проекты',
                subtitle: user.canManage
                    ? 'Просмотр и управление проектами'
                    : 'Просмотр проектов',
                onTap: () => _openSection(2)),
            _NavCard(
                icon: Icons.business_outlined,
                title: 'Клиенты',
                subtitle: user.canManage
                    ? 'Клиенты и контактные лица'
                    : 'Просмотр клиентов',
                onTap: () => _openSection(3)),
            if (user.isAdmin)
              _NavCard(
                  icon: Icons.people_outline,
                  title: 'Пользователи',
                  subtitle: 'Управление учётными записями и ролями (админ)',
                  onTap: () => _openSection(4)),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final bool loading;

  const _StatTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.loading});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, size: 26),
              const SizedBox(height: 6),
              loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('${value ?? '—'}',
                      style: Theme.of(context).textTheme.titleLarge),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: ListTile(
          leading: Icon(icon, size: 30),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
