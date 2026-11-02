/// Vacancy detail screen — hero `RealGlassCard` (true BackdropFilter blur),
/// full CRUD entry points and the vacancy's application funnel.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/glass_stack.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';
import 'applications_screen.dart';
import 'vacancy_form_screen.dart';

class VacancyDetailScreen extends StatefulWidget {
  final int vacancyId;
  const VacancyDetailScreen({super.key, required this.vacancyId});

  @override
  State<VacancyDetailScreen> createState() => _VacancyDetailScreenState();
}

class _VacancyDetailScreenState extends State<VacancyDetailScreen> {
  Map<String, dynamic>? _vacancy;
  CompanyItem? _company;
  Map<String, int> _funnel = {};
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final api = AppScope.read(context).api;
      final v = await api.get('/vacancies/${widget.vacancyId}')
          as Map<String, dynamic>;
      Object? company;
      try {
        company = await api.get('/companies/${v['company_id']}');
      } catch (_) {/* company may be deleted */}
      final counts = <String, int>{};
      // This funnel is vacancy-specific, so query its paginated applications.
      try {
        final rawApps = await api
            .get('/applications', {'vacancy_id': v['id'], 'page_size': 200});
        final items = (rawApps is Map && rawApps['items'] is List)
            ? rawApps['items'] as List
            : const [];
        for (final e in items) {
          if (e is! Map) continue;
          final st = e['status']?.toString();
          if (st != null) counts[st] = (counts[st] ?? 0) + 1;
        }
      } catch (_) {/* funnel is optional */}
      if (!mounted) return;
      setState(() {
        _vacancy = v;
        _company = company == null
            ? null
            : CompanyItem.fromJson(company as Map<String, dynamic>);
        _funnel = counts;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
        _vacancy = null;
      });
      showError(context, e);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              VacancyFormScreen(existing: VacancyItem.fromJson(_vacancy!))),
    );
    if (changed == true) _load();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, 'Удалить вакансию?',
        'Вакансия «${_vacancy!['title']}» и все её отклики будут удалены.');
    if (!ok) return;
    final api = AppScope.read(context).api;
    final done = await runGuarded(
        context, () => api.delete('/vacancies/${widget.vacancyId}'));
    if (done && mounted) Navigator.pop(context, true);
  }

  /// Self-service apply: any signed-in user can register a candidate
  /// application straight from the vacancy card (POST /applications).
  Future<void> _apply() async {
    final nameCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Откликнуться на вакансию'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtl,
                  decoration:
                      const InputDecoration(labelText: 'ФИО кандидата *')),
              const SizedBox(height: 10),
              TextField(
                  controller: emailCtl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail')),
              const SizedBox(height: 10),
              TextField(
                  controller: phoneCtl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Телефон')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () {
                  if (nameCtl.text.trim().length < 2) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Укажите ФИО (минимум 2 символа)')));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Отправить')),
          ],
        ),
      );
      if (submitted != true || !mounted) return;
      final api = AppScope.read(context).api;
      final ok = await runGuarded(context, () async {
        await api.post('/applications', {
          'vacancy_id': widget.vacancyId,
          'full_name': nameCtl.text.trim(),
          if (emailCtl.text.trim().isNotEmpty) 'email': emailCtl.text.trim(),
          if (phoneCtl.text.trim().isNotEmpty) 'phone': phoneCtl.text.trim(),
        });
      });
      if (ok && mounted) {
        AppScope.read(context).notifications.add(
              'Новый отклик',
              '${nameCtl.text.trim()} откликнулся на «${_vacancy?['title'] ?? 'вакансию'}».',
            );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Отклик отправлен — кандидат добавлен в воронку')));
        _load();
      }
    } finally {
      nameCtl.dispose();
      emailCtl.dispose();
      phoneCtl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.read(context).user;
    if (_loading) return const Scaffold(body: LoadingView());
    if (_vacancy == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Вакансия')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError == null
                    ? 'Вакансия не найдена'
                    : 'Не удалось загрузить вакансию'),
                const SizedBox(height: 12),
                if (_loadError != null)
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const GlassIcon(Glyph.refresh, size: 18),
                    label: const Text('Повторить'),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final v = _vacancy!;
    final item = VacancyItem.fromJson(v);
    final skills = ((v['skills'] as List?) ?? [])
        .map((e) => SkillItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(item.title, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          RealGlassCard(
            blur: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    if (item.remote)
                      const StatusChip(
                          label: 'Удалённо', color: Color(0xFF26C6DA)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _meta(Glyph.money, item.salaryLabel,
                        color: const Color(0xFF8CE99A)),
                    if (item.city != null) _meta(Glyph.pin, item.city!),
                    if (_company != null) _meta(Glyph.building, _company!.name),
                    _meta(Glyph.list,
                        '${_funnel.values.fold<int>(0, (a, b) => a + b)} откликов'),
                  ],
                ),
                if (skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in skills)
                        StatusChip(
                            label: s.name, color: const Color(0xFF7986CB)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          RealGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Описание вакансии',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  (v['description'] as String?)?.trim().isNotEmpty == true
                      ? v['description']
                      : 'Описание пока не заполнено.',
                  style: TextStyle(
                      height: 1.45,
                      color: appTextColor(context, opacity: 0.88)),
                ),
                const SizedBox(height: 10),
                Text('Обновлена: ${_fmtDate(item.updatedAt)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: appTextColor(context, opacity: 0.68))),
              ],
            ),
          ),
          if (_funnel.isNotEmpty)
            RealGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Воронка по вакансии',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  FunnelBars(counts: _funnel),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ApplicationsScreen(vacancyId: item.id)),
                      ),
                      icon: const GlassIcon(Glyph.kanban, size: 18),
                      label: const Text('Открыть отклики'),
                    ),
                  ),
                ],
              ),
            ),
          if (user?.canManage ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _edit,
                      icon: const GlassIcon(Glyph.edit, size: 18),
                      label: const Text('Редактировать'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEF5350)),
                      onPressed: _delete,
                      icon: const GlassIcon(Glyph.delete, size: 18),
                      label: const Text('Удалить'),
                    ),
                  ),
                ],
              ),
            )
          else
            // Worker sees the self-service apply CTA instead of CRUD buttons.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3ED9B8)),
                  onPressed: _apply,
                  icon: const GlassIcon(Glyph.send, size: 18),
                  label: const Text('Откликнуться'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _meta(Glyph g, String text, {Color? color}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassIcon(g, size: 16),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color ?? appTextColor(context, opacity: 0.85))),
        ],
      );

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
