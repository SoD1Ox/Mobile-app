/// Authenticated app shell: dashboard + tab navigation with an IndexedStack
/// so every tab keeps its state (search text, filters, loaded pages).
///
/// Role hierarchy (mirrors backend RBAC):
///   admin   — Главная · Вакансии · Кандидаты · Воронка · Компании · Пользователи;
///   manager — Главная · Вакансии · Кандидаты · Воронка · Компании;
///   worker  — Главная · Мои кейсы (назначенные отклики) · Вакансии.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/glass.dart';
import '../theme/glass_stack.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';
import 'applications_screen.dart';
import 'candidates_screen.dart';
import 'companies_screen.dart';
import 'users_screen.dart';
import 'vacancies_screen.dart';

/// Bottom-nav destination built from custom vector glyphs (no Material Icons).
class _Dest {
  final Glyph icon;
  final String label;
  const _Dest(this.icon, this.label);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _vacancyCount;
  int? _candidateCount;
  int? _newAppCount;
  int? _hiredCount;
  int? _myCaseCount; // assigned to the current user (worker/manager view)
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
    final scope = AppScope.of(context);
    final api = scope.api;
    final user = scope.user!;
    try {
      // Only the queries relevant to the role — fast dashboard, no waiting
      // for data the user cannot access anyway.
      final results = await Future.wait([
        api.get('/vacancies', {'page_size': 1}),
        if (user.canManage)
          api.get('/candidates', {'page_size': 1})
        else
          Future.value(null),
        if (user.canManage)
          api.get('/applications', {'page_size': 1, 'status': 'new'})
        else
          Future.value(null),
        if (user.canManage)
          api.get('/applications', {'page_size': 1, 'status': 'hired'})
        else
          Future.value(null),
        // «mine» is scoped by the server to the current user's assignments.
        api.get('/applications', {'page_size': 1, 'mine': true}),
      ]);
      if (!mounted) return;
      setState(() {
        _vacancyCount = results[0]['total'];
        _candidateCount = (results[1] as Map?)?['total'];
        _newAppCount = user.canManage ? (results[2] as Map?)?['total'] : null;
        _hiredCount = (results[3] as Map?)?['total'];
        _myCaseCount = results[4]['total'];
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

    // ----- role-aware tab sets -------------------------------------------------
    // Tabs and destinations are built together so indices always match.
    final tabs = <Widget>[];
    final dests = <_Dest>[];

    if (user.role == 'worker') {
      // Worker: personal queue first — it is their main workspace.
      // The dashboard is shown as "Главная" with a logout button.
      tabs.add(_dashboard(user, greeting, scope));
      dests.add(const _Dest(Glyph.dashboard, 'Главная'));
      tabs.add(const ApplicationsScreen(mineOnly: true));
      dests.add(const _Dest(Glyph.kanban, 'Мои кейсы'));
      tabs.add(const VacanciesScreen());
      dests.add(const _Dest(Glyph.briefcase, 'Вакансии'));
    } else {
      tabs.add(_dashboard(user, greeting, scope));
      dests.add(const _Dest(Glyph.dashboard, 'Главная'));
      tabs.add(const VacanciesScreen());
      dests.add(const _Dest(Glyph.briefcase, 'Вакансии'));
      tabs.add(const CandidatesScreen());
      dests.add(const _Dest(Glyph.people, 'Кандидаты'));
      tabs.add(const ApplicationsScreen());
      dests.add(const _Dest(Glyph.kanban, 'Воронка'));
      tabs.add(const CompaniesScreen());
      dests.add(const _Dest(Glyph.building, 'Компании'));
      if (user.isAdmin) {
        tabs.add(const UsersScreen());
        dests.add(const _Dest(Glyph.server, 'Люди'));
      }
    }

    if (_tab >= tabs.length) _tab = 0;

    return Scaffold(
      extendBody: true, // let content scroll under the glass nav bar
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        child: GlassPanel(
          child: _GlassNavBar(
            index: _tab,
            onTap: (i) => setState(() => _tab = i),
            destinations: dests,
          ),
        ),
      ),
    );
  }

  /// Dashboard tab content (greeting, stats, quick links to the sections).
  Widget _dashboard(AppUser user, String greeting, AppScope scope) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кадровое агентство'),
        actions: [
          GlassIconButton(Glyph.logout,
              tooltip: 'Выйти',
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
            // -------- greeting card (real glass: one BackdropFilter)
            RealGlassCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: kAccentColor.withOpacity(0.35),
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
                        Text('@${user.username} · ${user.email}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7))),
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
            const SizedBox(height: 16),

            // -------- quick stats (manager/admin see the whole funnel,
            // worker sees their own queue)
            Row(
              children: [
                Expanded(
                    child: _StatTile(
                        glyph: Glyph.briefcase,
                        label: 'Вакансии',
                        value: _vacancyCount,
                        loading: _statsLoading)),
                const SizedBox(width: 8),
                if (user.canManage)
                  Expanded(
                      child: _StatTile(
                          glyph: Glyph.people,
                          label: 'Кандидаты',
                          value: _candidateCount,
                          loading: _statsLoading))
                else
                  Expanded(
                      child: _StatTile(
                          glyph: Glyph.kanban,
                          label: 'Мои кейсы',
                          value: _myCaseCount,
                          loading: _statsLoading)),
              ],
            ),
            if (user.canManage) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _StatTile(
                          glyph: Glyph.send,
                          label: 'Новых откликов',
                          value: _newAppCount,
                          loading: _statsLoading)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _StatTile(
                          glyph: Glyph.chart,
                          label: 'Трудоустроено',
                          value: _hiredCount,
                          loading: _statsLoading)),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _StatTile(
                          glyph: Glyph.chart,
                          label: 'Трудоустроено',
                          value: _hiredCount,
                          loading: _statsLoading)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _StatTile(
                          glyph: Glyph.person,
                          label: 'Роль',
                          textValue: user.roleLabel,
                          loading: false)),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // -------- navigation (indices match the role tab set above)
            Text('Разделы', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _NavCard(
                glyph: Glyph.kanban,
                title: user.canManage ? 'Воронка найма' : 'Мои кейсы',
                subtitle: user.canManage
                    ? 'Kanban-доска: перетаскивание карточек между этапами'
                    : 'Отклики, назначенные лично вам',
                onTap: () => _openSection(user.canManage ? 3 : 1)),
            _NavCard(
                glyph: Glyph.briefcase,
                title: 'Вакансии',
                subtitle: 'Поиск, фильтры, пагинация'
                    '${user.canManage ? ', создание и правка' : ''}',
                onTap: () => _openSection(1)),
            if (user.canManage)
              _NavCard(
                  glyph: Glyph.people,
                  title: 'Кандидаты',
                  subtitle: 'База соискателей, заметки рекрутеров, история откликов',
                  onTap: () => _openSection(2)),
            if (user.canManage)
              _NavCard(
                  glyph: Glyph.building,
                  title: 'Компании',
                  subtitle: 'Партнёры и контактные лица',
                  onTap: () => _openSection(4)),
            if (user.isAdmin)
              _NavCard(
                  glyph: Glyph.server,
                  title: 'Пользователи',
                  subtitle: 'Управление учётными записями и ролями (админ)',
                  onTap: () => _openSection(5)),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final Glyph glyph;
  final String label;
  final int? value;
  final String? textValue;
  final bool loading;

  const _StatTile(
      {required this.glyph,
      required this.label,
      this.value,
      this.textValue,
      required this.loading});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              GlassIcon(glyph, size: 26),
              const SizedBox(height: 6),
              loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(textValue ?? '${value ?? '—'}',
                      style: Theme.of(context).textTheme.titleLarge),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

class _NavCard extends StatelessWidget {
  final Glyph glyph;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard(
      {required this.glyph,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: ListTile(
          leading: GlassIcon(glyph, size: 30),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const GlassIcon(Glyph.chevronRight, size: 20),
          onTap: onTap,
        ),
      );
}

/// Custom glass bottom navigation bar built from vector glyphs — replaces
/// NavigationBar/Icons entirely. Animated selection pill, no icon font.
class _GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<_Dest> destinations;

  const _GlassNavBar(
      {required this.index, required this.onTap, required this.destinations});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 68,
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: i == index
                          ? const LinearGradient(
                              colors: [Color(0x593ED9B8), Color(0x263ED9B8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight)
                          : null,
                      border: Border.all(
                          color: i == index
                              ? const Color(0x663ED9B8)
                              : Colors.transparent),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GlassIcon(destinations[i].icon,
                            size: 21,
                            color: i == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.55)),
                        const SizedBox(height: 3),
                        Text(destinations[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: i == index
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: i == index
                                    ? Colors.white
                                    : Colors
                                        .white.withOpacity(0.55))),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
