/// Vacancy detail screen — hero `RealGlassCard` (true BackdropFilter blur),
/// full CRUD entry points and the vacancy's application funnel.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/glass.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = AppScope.read(context).api;
    try {
      final v = await api.get('/vacancies/${widget.vacancyId}')
          as Map<String, dynamic>;
      Object? company;
      try {
        company = await api.get('/companies/${v['company_id']}');
      } catch (_) {/* company may be deleted */}
      final counts = <String, int>{};
      for (final s in ApplicationItem.pipelineOrder) {
        try {
          final raw = await api
              .get('/applications', {'vacancy_id': v['id'], 'status': s, 'page_size': 1});
          counts[s] = raw['total'] as int;
        } catch (_) {
          counts[s] = 0;
        }
      }
      if (!mounted) return;
      setState(() {
        _vacancy = v;
        _company = company == null ? null : CompanyItem.fromJson(company as Map<String, dynamic>);
        _funnel = counts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => VacancyFormScreen(existing: VacancyItem.fromJson(_vacancy!))),
    );
    if (changed == true) _load();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, 'Удалить вакансию?',
        'Вакансия «${_vacancy!['title']}» и все её отклики будут удалены.');
    if (!ok) return;
    final api = AppScope.read(context).api;
    final done = await runGuarded(context, () => api.delete('/vacancies/${widget.vacancyId}'));
    if (done && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.read(context).user;
    if (_loading) return const Scaffold(body: LoadingView());
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
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    if (item.remote)
                      const StatusChip(label: 'Удалённо', color: Color(0xFF26C6DA)),
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
                    _meta(Glyph.list, '${_funnel.values.fold<int>(0, (a, b) => a + b)} откликов'),
                  ],
                ),
                if (skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in skills)
                        StatusChip(label: s.name, color: const Color(0xFF7986CB)),
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
                      height: 1.45, color: Colors.white.withOpacity(0.85)),
                ),
                const SizedBox(height: 10),
                Text('Обновлена: ${_fmtDate(item.updatedAt)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withOpacity(0.5))),
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
                            builder: (_) => ApplicationsScreen(
                                initialVacancyId: item.id,
                                initialVacancyTitle: item.title)),
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
                  color: color ?? Colors.white.withOpacity(0.8))),
        ],
      );

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
