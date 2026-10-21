/// Home screen: greeting, current-user info and navigation to every section.
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
      setState(() {
        _taskCount = results[0]['total'];
        _projectCount = results[1]['total'];
        _clientCount = results[2]['total'];
        _statsLoading = false;
      });
    } catch (e) {
      setState(() => _statsLoading = false);
      if (mounted) showError(context, e);
    }
  }

  void _push(Widget screen) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => screen));

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Tracker'),
        actions: [
          IconButton(
              tooltip: 'Выйти',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final yes = await confirmDialog(context, 'Выйти?', 'Сессия будет завершена.',
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
                onTap: () => _push(const TasksScreen())),
            _NavCard(
                icon: Icons.folder_outlined,
                title: 'Проекты',
                subtitle: user.canManage
                    ? 'Просмотр и управление проектами'
                    : 'Просмотр проектов',
                onTap: () => _push(const ProjectsScreen())),
            _NavCard(
                icon: Icons.business_outlined,
                title: 'Клиенты',
                subtitle: user.canManage
                    ? 'Клиенты и контактные лица'
                    : 'Просмотр клиентов',
                onTap: () => _push(const ClientsScreen())),
            if (user.isAdmin)
              _NavCard(
                  icon: Icons.people_outline,
                  title: 'Пользователи',
                  subtitle: 'Управление учётными записями и ролями (админ)',
                  onTap: () => _push(const UsersScreen())),
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
