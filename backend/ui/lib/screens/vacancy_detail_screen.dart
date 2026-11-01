/// Vacancy detail screen: full info + skills + applications pipeline.
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
  VacancyItem? _vacancy;
  String _companyName = '';
  int _appCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = AppScope.read(context).api;
      final results = await Future.wait([
        api.get('/vacancies/${widget.vacancyId}'),
        api.get('/applications',
            {'vacancy_id': widget.vacancyId, 'page_size': 1}),
      ]);
      final v = VacancyItem.fromJson(Map<String, dynamic>.from(results[0] as Map));
      String cname = '';
      try {
        final c = await api.get('/companies/${v.companyId}');
        cname = (c as Map)['name'] as String? ?? '';
      } catch (_) {/* company may be deleted */}
      if (!mounted) return;
      setState(() {
        _vacancy = v;
        _companyName = cname;
        _appCount = results[1]['total'] as int? ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _delete() async {
    final yes = await confirmDialog(context, 'Удалить вакансию?',
        'Вместе с ней будут удалены все отклики.');
    if (!yes || !mounted) return;
    final ok = await runGuarded(context, () async {
      await AppScope.read(context).api.delete('/vacancies/${widget.vacancyId}');
    });
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.read(context).user;
    final v = _vacancy;
    return Scaffold(
      appBar: AppBar(
        title: Text(v?.title ?? 'Вакансия'),
        actions: [
          if (v != null && (user?.canManage ?? false)) ...[
            GlassIconButton(Glyph.edit,
                onPressed: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => VacancyFormScreen(existing: v)),
                  );
                  if (changed == true) _load();
                }),
            GlassIconButton(Glyph.delete, onPressed: _delete),
          ],
        ],
      ),
      body: _loading
          ? const LoadingView()
          : v == null
              ? const Center(child: Text('Вакансия не найдена'))
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    // Hero card — REAL glass (single BackdropFilter)
                    RealGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(v.title,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800)),
                                ),
                                if (v.remote)
                                  const StatusChip(
                                      label: 'Удалённо',
                                      color: Color(0xFF26C6DA)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const GlassIcon(Glyph.money, size: 17),
                                const SizedBox(width: 6),
                                Text(v.salaryLabel,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF8CE99A))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _row(Glyph.building,
                                _companyName.isEmpty ? 'Компания удалена' : _companyName),
                            if (v.city != null)
                              _row(Glyph.pin, v.city!),
                            _row(Glyph.people, '$_appCount откликов'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (v.skills.isNotEmpty) ...[
                      GlassListCard(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Навыки',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final s in v.skills)
                                    StatusChip(
                                        label: s.name, color: kAccentColor),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if ((v.description ?? '').isNotEmpty)
                      GlassListCard(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Описание',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Text(v.description!,
                                  style: const TextStyle(height: 1.45)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ApplicationsScreen(vacancyId: v.id)),
                      ),
                      icon: const GlassIcon(Glyph.kanban, size: 18),
                      label: Text('Отклики (${_appCount})'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _row(Glyph g, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            GlassIcon(g, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: TextStyle(color: Colors.white.withOpacity(0.85)))),
          ],
        ),
      );
}
