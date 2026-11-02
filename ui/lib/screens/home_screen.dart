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
import '../notifications.dart';
import '../theme/glass.dart';
import '../theme/glass_stack.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';
import 'applications_screen.dart';
import 'candidates_screen.dart';
import 'companies_screen.dart';
import 'users_screen.dart';
import 'settings_screen.dart';
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

  /// Each counter loads independently: one slow/failed request can never
  /// freeze the whole dashboard ("infinite loading" fix).
  bool _loadingVacancies = true;
  bool _loadingCandidates = true;
  bool _loadingNewApps = true;
  bool _loadingHired = true;
  bool _loadingMine = true;

  /// Currently selected bottom-navigation tab.
  int _tab = 0;
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Runs one stats query and patches only its own tile + loading flag.
  Future<void> _stat(
      String path,
      Map<String, dynamic> params,
      void Function(int?) apply,
      void Function(bool) setLoading,
      List<Object> failures) async {
    int? result;
    try {
      final raw = await AppScope.read(context).api.get(path, params);
      final map = raw as Map?;
      var total = map?['total'];
      // Fallback: if the endpoint has no `total` (older backend), count items.
      if (total == null && map != null && map['items'] is List) {
        total = (map['items'] as List).length;
      }
      result = total is int ? total : int.tryParse('${total ?? ''}');
    } catch (e) {
      // Leave a visible error on the dashboard instead of silently replacing
      // failed requests with a dash.
      failures.add(e);
      result = null;
    } finally {
      if (mounted) {
        setState(() {
          apply(result);
          setLoading(false);
        });
      }
    }
  }

  Future<void> _loadStats() async {
    final user = AppScope.read(context).user;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingVacancies = false;
          _loadingCandidates = false;
          _loadingNewApps = false;
          _loadingHired = false;
          _loadingMine = false;
        });
      }
      return;
    }
    setState(() {
      _loadingVacancies = true;
      _loadingCandidates = user.canManage;
      _loadingNewApps = user.canManage;
      _loadingHired = true;
      _loadingMine = true;
      if (!user.canManage) {
        _candidateCount = null;
        _newAppCount = null;
      }
    });
    final failures = <Object>[];
    final requests = <Future<void>>[];
    requests.add(_stat('/vacancies', {'page_size': 1}, (v) => _vacancyCount = v,
        (b) => _loadingVacancies = b, failures));
    requests.add(_stat('/applications', {'page_size': 1, 'mine': true},
        (v) => _myCaseCount = v, (b) => _loadingMine = b, failures));
    // Hired tile: a worker's scoped list can legitimately be empty, so for
    // them we count their own cases that reached "hired" via the items array.
    requests.add(_stat('/applications', {'page_size': 1, 'status': 'hired'},
        (v) => _hiredCount = v, (b) => _loadingHired = b, failures));
    if (user.canManage) {
      requests.add(_stat('/candidates', {'page_size': 1},
          (v) => _candidateCount = v, (b) => _loadingCandidates = b, failures));
      requests.add(_stat('/applications', {'page_size': 1, 'status': 'new'},
          (v) => _newAppCount = v, (b) => _loadingNewApps = b, failures));
    }
    await Future.wait(requests);
    if (mounted && failures.isNotEmpty) {
      showError(context, failures.first);
    }
  }

  void _openSection(int index) => setState(() {
        _tab = index;
        _visitedTabs.add(index);
      });

  Future<void> _showNotifications(NotificationStore notifications) async {
    notifications.markAllSeen();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: GlassPanel(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.68,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: ListenableBuilder(
                listenable: notifications,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const GlassIcon(Glyph.bell, size: 21),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text('Уведомления',
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                        if (notifications.items.isNotEmpty)
                          TextButton(
                            onPressed: notifications.clear,
                            child: const Text('Очистить'),
                          ),
                        GlassIconButton(
                          Glyph.close,
                          tooltip: 'Закрыть',
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Expanded(
                      child: notifications.items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GlassIcon(
                                    Glyph.bell,
                                    size: 34,
                                    color: appTextColor(context, opacity: 0.5),
                                  ),
                                  const SizedBox(height: 10),
                                  Text('Пока тихо',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Здесь появятся важные события и изменения.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: appTextColor(context,
                                            opacity: 0.68)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: notifications.items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 7),
                              itemBuilder: (context, index) {
                                final item = notifications.items[index];
                                return GlassListCard(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: GlassIcon(Glyph.dot,
                                              size: 12, color: kAccentColor),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(item.title,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              const SizedBox(height: 3),
                                              Text(item.body,
                                                  style: TextStyle(
                                                      color: appTextColor(
                                                          context,
                                                          opacity: 0.78))),
                                              const SizedBox(height: 5),
                                              Text(_notificationTime(item.at),
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: appTextColor(
                                                          context,
                                                          opacity: 0.58))),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _notificationTime(DateTime at) {
    final elapsed = DateTime.now().difference(at);
    if (elapsed.inMinutes < 1) return 'Только что';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} мин. назад';
    final local = at.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Сегодня, $time';
    }
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} · $time';
  }

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
      dests.add(const _Dest(Glyph.send, 'Отклики'));
      tabs.add(const CompaniesScreen());
    }

    if (_tab >= tabs.length) _tab = 0;

    return Scaffold(
      extendBody: true, // let content scroll under the glass nav bar
      body: IndexedStack(
        index: _tab,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _visitedTabs.contains(i) ? tabs[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        child: GlassPanel(
          child: _GlassNavBar(
            index: _tab < dests.length ? _tab : 0,
            onTap: _openSection,
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
        title: Text(user.isAdmin
            ? 'Панель администратора'
            : user.isManager
                ? 'Панель менеджера'
                : 'Мой рабочий стол'),
        actions: [
          GlassIconButton(
            Glyph.settings,
            tooltip: 'Настройки',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          ListenableBuilder(
            listenable: scope.notifications,
            builder: (context, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                GlassIconButton(
                  Glyph.bell,
                  tooltip: 'Уведомления',
                  onPressed: () => _showNotifications(scope.notifications),
                ),
                if (scope.notifications.unreadCount > 0)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: kCoralColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        scope.notifications.unreadCount > 99
                            ? '99+'
                            : '${scope.notifications.unreadCount}',
                        style: const TextStyle(
                            color: Color(0xFF17332D),
                            fontSize: 9,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GlassIconButton(Glyph.logout, tooltip: 'Выйти', onPressed: () async {
            final yes = await confirmDialog(
                context, 'Выйти?', 'Сессия будет завершена.',
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
            Text(user.canManage ? 'Обзор команды' : 'Мой обзор',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 7),
            // High contrast role banner: the greeting stays readable at a glance.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF203A30)
                    : const Color(0xFF245944),
                borderRadius: BorderRadius.circular(22),
                border:
                    Border.all(color: const Color(0xFFB8E76A).withOpacity(.44)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            user.canManage
                                ? 'РАБОЧЕЕ ПРОСТРАНСТВО'
                                : 'МОЙ КАБИНЕТ',
                            style: const TextStyle(
                                color: Color(0xFFB8E76A),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1)),
                        const SizedBox(height: 7),
                        Text('$greeting, ${user.fullName}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                height: 1.12,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 7),
                        Text('@${user.username} · ${user.email}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFFD1DDD3), fontSize: 12)),
                        const SizedBox(height: 11),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.1),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: Colors.white.withOpacity(.2)),
                          ),
                          child: Text(user.roleLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: const Color(0xFFB8E76A),
                    child: Text(user.fullName.characters.first.toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFF193B2D),
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
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
                        loading: _loadingVacancies)),
                const SizedBox(width: 8),
                if (user.canManage)
                  Expanded(
                      child: _StatTile(
                          glyph: Glyph.people,
                          label: 'Кандидаты',
                          value: _candidateCount,
                          loading: _loadingCandidates))
                else
                  Expanded(
                      child: _StatTile(
                          glyph: Glyph.kanban,
                          label: 'Мои кейсы',
                          value: _myCaseCount,
                          loading: _loadingMine)),
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
                          loading: _loadingNewApps)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _StatTile(
                          glyph: Glyph.chart,
                          label: 'Трудоустроено',
                          value: _hiredCount,
                          loading: _loadingHired)),
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
                          loading: _loadingHired)),
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

            // Role-focused actions: each role starts with its daily workflow.
            Text(user.canManage ? 'Рабочие разделы' : 'Мои разделы',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (user.canManage) ...[
              _NavCard(
                  glyph: Glyph.send,
                  title: 'Отклики',
                  subtitle: 'Распределение заявок по этапам',
                  onTap: () => _openSection(3)),
              _NavCard(
                  glyph: Glyph.briefcase,
                  title: 'Вакансии',
                  subtitle: 'Создавать позиции и управлять публикациями',
                  onTap: () => _openSection(1)),
              _NavCard(
                  glyph: Glyph.people,
                  title: 'Кандидаты',
                  subtitle:
                      'База соискателей, заметки рекрутеров, история откликов',
                  onTap: () => _openSection(2)),
              _NavCard(
                  glyph: Glyph.building,
                  title: 'Компании',
                  subtitle: 'Партнёры и контактные лица',
                  onTap: () => _openSection(4)),
            ] else ...[
              _NavCard(
                  glyph: Glyph.kanban,
                  title: 'Мои отклики',
                  subtitle: 'Назначенные вам заявки и их текущий статус',
                  onTap: () => _openSection(1)),
              _NavCard(
                  glyph: Glyph.briefcase,
                  title: 'Найти вакансию',
                  subtitle: 'Поиск по городу, формату работы и зарплате',
                  onTap: () => _openSection(2)),
            ],
            _NavCard(
                glyph: Glyph.star,
                title: 'Избранное',
                subtitle: 'Сохранённые вакансии',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        const VacanciesScreen(initialFavorites: true)))),
            if (user.isAdmin)
              _NavCard(
                  glyph: Glyph.server,
                  title: 'Пользователи',
                  subtitle: 'Учётные записи и распределение ролей',
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UsersScreen()))),
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: GlassIcon(glyph,
                        size: 18, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(textValue ?? '${value ?? '—'}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: GlassIcon(glyph,
                size: 23, color: Theme.of(context).colorScheme.primary),
          ),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle:
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: GlassIcon(Glyph.chevronRight,
              size: 20,
              color: Theme.of(context).colorScheme.primary.withOpacity(.8)),
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
                          ? LinearGradient(
                              colors: [
                                  Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.2),
                                  Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.08),
                                ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight)
                          : null,
                      border: Border.all(
                          color: i == index
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.48)
                              : Colors.transparent),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GlassIcon(destinations[i].icon,
                            size: 21,
                            color: i == index
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .color!
                                    .withOpacity(0.55)),
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
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .color!
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
