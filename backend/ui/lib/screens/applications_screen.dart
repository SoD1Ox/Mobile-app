/// Applications — the high-volume entity (hundreds of records) shown as a
/// Kanban hiring pipeline: horizontally scrollable columns per stage, cards
/// move between stages via PATCH /applications/{id}.  Pagination per column.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';

class ApplicationsScreen extends StatefulWidget {
  /// Optional pre-filter: show only applications of one vacancy.
  final int? initialVacancyId;
  final String? initialVacancyTitle;
  const ApplicationsScreen(
      {super.key, this.initialVacancyId, this.initialVacancyTitle});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  static const _pageSize = 30;

  /// stage -> loaded page of applications
  final Map<String, List<ApplicationItem>> _byStage = {};
  final Map<String, int> _totals = {};

  List<CandidateItem> _candidates = [];
  List<VacancyItem> _vacancies = [];
  Map<int, String> _candidateNames = {};
  Map<int, String> _vacancyTitles = {};

  bool _bootLoading = true;
  int? get _vacancyFilter => widget.initialVacancyId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final api = AppScope.read(context).api;
    try {
      // Warm up lookup maps from the first pages of candidates/vacancies.
      final results = await Future.wait([
        for (final s in ApplicationItem.pipelineOrder)
          api.get('/applications', {
            'status': s,
            'page_size': _pageSize,
            if (_vacancyFilter != null) 'vacancy_id': _vacancyFilter,
          }),
        api.get('/candidates', {'page_size': 200}),
        api.get('/vacancies', {'page_size': 200}),
      ]);
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < ApplicationItem.pipelineOrder.length; i++) {
          final p = DataPage.fromJson(
              results[i] as Map<String, dynamic>, ApplicationItem.fromJson);
          _byStage[ApplicationItem.pipelineOrder[i]] = p.items;
          _totals[ApplicationItem.pipelineOrder[i]] = p.total;
        }
        _candidates = DataPage.fromJson(
                results[ApplicationItem.pipelineOrder.length] as Map<String, dynamic>,
                CandidateItem.fromJson)
            .items;
        _vacancies = DataPage.fromJson(
                results[ApplicationItem.pipelineOrder.length + 1] as Map<String, dynamic>,
                VacancyItem.fromJson)
            .items;
        _candidateNames = {for (final c in _candidates) c.id: c.fullName};
        _vacancyTitles = {for (final v in _vacancies) v.id: v.title};
        _bootLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _bootLoading = false);
      showError(context, e);
    }
  }

  Future<void> _ensureName(int candidateId) async {
    if (_candidateNames.containsKey(candidateId)) return;
    final api = AppScope.read(context).api;
    try {
      final raw = await api.get('/candidates/$candidateId') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _candidateNames[candidateId] = raw['full_name'] as String);
    } catch (_) {/* keep placeholder */}
  }

  Future<void> _move(ApplicationItem a, String to) async {
    if (a.status == to) return;
    final api = AppScope.read(context).api;
    // Optimistic update for snappy kanban feel.
    setState(() {
      _byStage[a.status]?.removeWhere((x) => x.id == a.id);
      _byStage[to] = [a, ...(_byStage[to] ?? [])];
      _totals[a.status] = (_totals[a.status] ?? 1) - 1;
      _totals[to] = (_totals[to] ?? 0) + 1;
    });
    try {
      await api.patch('/applications/${a.id}', {'status': to});
    } catch (e) {
      if (mounted) {
        showError(context, e);
        _bootstrap(); // rollback: reload everything
      }
    }
  }

  ApplicationItem? findById(int id) {
    for (final list in _byStage.values) {
      for (final x in list) {
        if (x.id == id) return x;
      }
    }
    return null;
  }

  Future<void> _openNewApplication() async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewApplicationSheet(
        candidates: _candidates,
        vacancies: _vacancies,
      ),
    );
    if (res == true) _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    if (_bootLoading) return const Scaffold(body: LoadingView());
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialVacancyTitle == null
            ? 'Воронка найма'
            : 'Отклики: ${widget.initialVacancyTitle}'),
        actions: [
          GlassIconButton(Glyph.add,
              tooltip: 'Новый отклик', onPressed: _openNewApplication),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 96),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final stage in ApplicationItem.pipelineOrder)
              _KanbanColumn(
                stage: stage,
                items: _byStage[stage] ?? [],
                total: _totals[stage] ?? 0,
                nameOf: (id) => _candidateNames[id] ?? 'Кандидат #$id',
                vacancyOf: (id) => _vacancyTitles[id] ?? 'Вакансия #$id',
                onMove: _move,
                ensureName: _ensureName,
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String stage;
  final List<ApplicationItem> items;
  final int total;
  final String Function(int) nameOf;
  final String Function(int) vacancyOf;
  final void Function(ApplicationItem, String) onMove;

  const _KanbanColumn({
    required this.stage,
    required this.items,
    required this.total,
    required this.nameOf,
    required this.vacancyOf,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(stage);
    final idx = ApplicationItem.pipelineOrder.indexOf(stage);
    return SizedBox(
      width: 280,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('${ApplicationItem.statusLabels[stage]} ($total)',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final a in items)
                    _DraggableAppCard(
                      a: a,
                      stage: stage,
                      name: nameOf(a.candidateId),
                      vacancy: vacancyOf(a.vacancyId),
                      idx: idx,
                      onMove: onMove,
                    ),
                  if (items.isEmpty)
                    DropTargetHint(
                      color: color,
                      onDropId: (id) {
                        final all = context
                            .findAncestorStateOfType<_ApplicationsScreenState>()!;
                        final app = all.findById(id);
                        if (app != null) onMove(app, stage);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty-column drop zone that accepts dragged card ids.
class DropTargetHint extends StatelessWidget {
  final Color color;
  final void Function(int id) onDropId;
  const DropTargetHint({super.key, required this.color, required this.onDropId});

  @override
  Widget build(BuildContext context) => DragTarget<int>(
        onAcceptWithDetails: (d) => onDropId(d.data),
        builder: (context, candidate, _) => Container(
          height: 90,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: kGlassRadius,
            border: Border.all(
                color: candidate.isNotEmpty
                    ? color
                    : Colors.white.withOpacity(0.12),
                strokeAlign: BorderSide.strokeAlignInside),
          ),
          child: Center(
            child: Text('Перетащите карточку сюда',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 12.5)),
          ),
        ),
      );
}

/// One kanban card: draggable + drop-target so cards can be moved between
/// columns with a finger/mouse drag; arrow buttons do the same step-by-step.
class _DraggableAppCard extends StatelessWidget {
  final ApplicationItem a;
  final String stage;
  final String name;
  final String vacancy;
  final int idx;
  final void Function(ApplicationItem, String) onMove;

  const _DraggableAppCard({
    required this.a,
    required this.stage,
    required this.name,
    required this.vacancy,
    required this.idx,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) => DragTarget<int>(
        onAcceptWithDetails: (d) {
          if (d.data == a.id) return; // dropped onto itself
          final all =
              context.findAncestorStateOfType<_ApplicationsScreenState>()!;
          final app = all.findById(d.data);
          if (app != null) onMove(app, stage);
        },
        builder: (context, candidate, _) => Draggable<int>(
          data: a.id,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: 250, child: _buildCard(highlight: false)),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: _buildCard(highlight: false)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              borderRadius: kGlassRadius,
              border: Border.all(
                  color: candidate.isNotEmpty
                      ? statusColor(stage).withOpacity(0.8)
                      : Colors.transparent),
            ),
            child: _buildCard(highlight: candidate.isNotEmpty),
          ),
        ),
      );

  Widget _buildCard({required bool highlight}) => _AppCard(
        a: a,
        name: name,
        vacancy: vacancy,
        onNext: idx < ApplicationItem.pipelineOrder.length - 1
            ? () => onMove(a, ApplicationItem.pipelineOrder[idx + 1])
            : null,
        onPrev: idx > 0
            ? () => onMove(a, ApplicationItem.pipelineOrder[idx - 1])
            : null,
        onReject: a.status == 'rejected'
            ? null
            : () => onMove(a, 'rejected'),
      );
}

class _AppCard extends StatelessWidget {
  final ApplicationItem a;
  final String name;
  final String vacancy;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;
  final VoidCallback? onReject;

  const _AppCard({
    required this.a,
    required this.name,
    required this.vacancy,
    this.onNext,
    this.onPrev,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return GlassListCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 3),
            Text(vacancy,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                      '${a.updatedAt.day.toString().padLeft(2, '0')}.'
                      '${a.updatedAt.month.toString().padLeft(2, '0')} '
                      '${a.updatedAt.hour.toString().padLeft(2, '0')}:${a.updatedAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.white.withOpacity(0.4))),
                ),
                if (onPrev != null)
                  GlassIconButton(Glyph.chevronLeft,
                      size: 16, tooltip: 'Назад по воронке', onPressed: onPrev),
                if (onNext != null)
                  GlassIconButton(Glyph.chevronRight,
                      size: 16, tooltip: 'Следующий этап', onPressed: onNext),
                if (onReject != null)
                  GlassIconButton(Glyph.close,
                      size: 16,
                      color: const Color(0xFFEF5350),
                      tooltip: 'Отказ',
                      onPressed: onReject),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: create an application (candidate → vacancy), POST /applications.
class _NewApplicationSheet extends StatefulWidget {
  final List<CandidateItem> candidates;
  final List<VacancyItem> vacancies;
  const _NewApplicationSheet({required this.candidates, required this.vacancies});

  @override
  State<_NewApplicationSheet> createState() => _NewApplicationSheetState();
}

class _NewApplicationSheetState extends State<_NewApplicationSheet> {
  int? _candidateId;
  int? _vacancyId;
  bool _saving = false;

  Future<void> _create() async {
    if (_candidateId == null || _vacancyId == null) {
      showError(context, ApiException(0, 'Выберите кандидата и вакансию'));
      return;
    }
    final api = AppScope.read(context).api;
    setState(() => _saving = true);
    try {
      await api.post('/applications',
          {'candidate_id': _candidateId, 'vacancy_id': _vacancyId});
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Новый отклик',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          AppDropdown<int>(
            label: 'Кандидат',
            value: _candidateId,
            onChanged: (v) => setState(() => _candidateId = v),
            items: [
              for (final c in widget.candidates)
                DropdownMenuItem(value: c.id, child: Text(c.fullName)),
            ],
          ),
          AppDropdown<int>(
            label: 'Вакансия',
            value: _vacancyId,
            onChanged: (v) => setState(() => _vacancyId = v),
            items: [
              for (final v in widget.vacancies)
                DropdownMenuItem(value: v.id, child: Text(v.title)),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _saving ? null : _create,
            icon: const GlassIcon(Glyph.send, size: 18),
            label: Text(_saving ? 'Создание…' : 'Оформить отклик'),
          ),
        ],
      ),
    );
  }
}
