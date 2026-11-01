/// Authenticated app shell of the staffing agency: dashboard + tab
/// navigation (Вакансии / Кандидаты / Воронка найма / Компании / Люди) built
/// on an IndexedStack so every tab keeps its state (search text, filters,
/// loaded pages) while switching tabs.  The bottom bar is a real frosted-glass
/// panel (BackdropFilter blur) — the only persistent blurred layer in the app.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/glass.dart';
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
  int? _companyCount;
  Map<String, int>? _funnel;
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
        api.get('/vacancies', {'page_size': 1}),
        api.get('/candidates', {'page_size': 1}),
        api.get('/companies', {'page_size': 1}),
        for (final s in ApplicationItem.pipelineOrder)
          api.get('/applications', {'status': s, 'page_size': 1}),
      ]);
      if (!mounted) return;
      setState(() {
        _vacancyCount = results[0]['total'];
        _candidateCount = results[1]['total'];
        _companyCount = results[2]['total'];
        _funnel = {
          for (var i = 0; i < ApplicationItem.pipelineOrder.length; i++)
            ApplicationItem.pipelineOrder[i]: results[3 + i]['total'] as int,
        };
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
      const VacanciesScreen(),
      const CandidatesScreen(),
      const ApplicationsScreen(),
      const CompaniesScreen(),
      if (user.isAdmin) const UsersScreen(),
    ];

    return Scaffold(
      extendBody: true, // let content scroll under the glass nav bar
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        child: GlassPanel(
          child: _GlassNavBar(
            index: _tab,
            onTap: (i) => setState(() => _tab = i),
            destinations: [
              const _Dest(Glyph.dashboard, 'Главная'),
              const _Dest(Glyph.briefcase, 'Вакансии'),
              const _Dest(Glyph.people, 'Кандидаты'),
              const _Dest(Glyph.kanban, 'Воронка'),
              const _Dest(Glyph.building, 'Компании'),
              if (user.isAdmin) const _Dest(Glyph.person, 'Люди'),
            ],
          ),
        ),
      ),
    );
  }

  /// Dashboard tab content (greeting, stats, hiring funnel, quick links).
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
                        glyph: Glyph.briefcase,
                        label: 'Вакансии',
                        value: _vacancyCount,
                        loading: _statsLoading)),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatTile(
                        glyph: Glyph.people,
                        label: 'Кандидаты',
                        value: _candidateCount,
                        loading: _statsLoading)),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatTile(
                        glyph: Glyph.building,
                        label: 'Компании',
                        value: _companyCount,
                        loading: _statsLoading)),
              ],
            ),
            const SizedBox(height: 16),

            // -------- hiring funnel widget (our feature #1)
            Text('Воронка найма',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _FunnelCard(funnel: _funnel, loading: _statsLoading),
            const SizedBox(height: 16),

            // -------- navigation
            Text('Разделы', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _NavCard(
                glyph: Glyph.briefcase,
                title: 'Вакансии',
                subtitle: 'Поиск, фильтры, бесконечная прокрутка, избранное',
                onTap: () => _openSection(1)),
            _NavCard(
                glyph: Glyph.people,
                title: 'Кандидаты',
                subtitle: user.canManage
                    ? 'База соискателей, заметки рекрутеров'
                    : 'Просмотр базы соискателей',
                onTap: () => _openSection(2)),
            _NavCard(
                glyph: Glyph.kanban,
                title: 'Воронка найма',
                subtitle: user.canManage
                    ? 'Kanban: отклик → интервью → оффер → найм'
                    : 'Отклики по этапам подбора',
                onTap: () => _openSection(3)),
            _NavCard(
                glyph: Glyph.building,
                title: 'Компании',
                subtitle: user.canManage
                    ? 'Партнёры агентства и их вакансии'
                    : 'Партнёрские компании',
                onTap: () => _openSection(4)),
            if (user.isAdmin)
              _NavCard(
                  glyph: Glyph.person,
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
  final bool loading;

  const _StatTile(
      {required this.glyph,
      required this.label,
      required this.value,
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
                  : Text('${value ?? '—'}',
                      style: Theme.of(context).textTheme.titleLarge),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

/// Animated horizontal funnel chart of application stages
/// (new → review → interview → offer → hired).  Painted with CustomPaint —
/// no external chart packages.
class _FunnelCard extends StatelessWidget {
  final Map<String, int>? funnel;
  final bool loading;

  const _FunnelCard({required this.funnel, required this.loading});

  @override
  Widget build(BuildContext context) {
    final f = funnel;
    if (loading || f == null) {
      return const Card(
          child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator())));
    }
    final stages = ApplicationItem.pipelineOrder;
    final maxV = stages.map((s) => f[s] ?? 0).fold<int>(1, (a, b) => a > b ? a : b);
    final hired = f['hired'] ?? 0;
    final allNew = f['new'] ?? 0;
    final conv = allNew == 0 ? null : (hired * 100 / allNew);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in stages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                        width: 118,
                        child: Text(ApplicationItem.statusLabels[s]!,
                            style: const TextStyle(fontSize: 13))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: (f[s] ?? 0) / maxV),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: v.clamp(0.02, 1.0),
                            child: Container(
                              height: 16,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  statusColor(s).withOpacity(0.9),
                                  statusColor(s).withOpacity(0.45),
                                ]),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                        width: 34,
                        child: Text('${f[s] ?? 0}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
            if (conv != null) ...[
              const Divider(color: Colors.white24),
              Row(
                children: [
                  const GlassIcon(Glyph.chart, size: 16),
                  const SizedBox(width: 6),
                  Text(
                      'Конверсия в найм: ${conv.toStringAsFixed(1)}%  ·  трудоустроено $hired',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withOpacity(0.75))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
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
                              colors: [Color(0x595B8CFF), Color(0x265B8CFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight)
                          : null,
                      border: Border.all(
                          color: i == index
                              ? const Color(0x665B8CFF)
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
                                    : Colors.white
                                        .withOpacity(0.55))),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
