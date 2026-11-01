/// Hiring pipeline board (kanban): applications grouped by stage.
/// Managers/admins drag cards between columns — each drop is a PATCH to the
/// API, so moving a card is a real server operation with error feedback.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/glass.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';
import 'candidate_detail_screen.dart';

class ApplicationsScreen extends StatefulWidget {
  final int? vacancyId; // null => all vacancies
  const ApplicationsScreen({super.key, this.vacancyId});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  List<ApplicationItem> _items = [];
  final Map<int, String> _candidateNames = {};
  final Map<int, String> _vacancyTitles = {};
  bool _loading = true;
  bool _dragging = false;

  static const _columns = ApplicationItem.pipelineOrder;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = AppScope.read(context).api;
      final raw = await api.get('/applications', {
        'page_size': 200,
        if (widget.vacancyId != null) 'vacancy_id': widget.vacancyId,
      });
      final page = DataPage.fromJson(raw, ApplicationItem.fromJson);
      final candIds = page.items.map((e) => e.candidateId).toSet();
      final vacIds = page.items.map((e) => e.vacancyId).toSet();
      final names = <int, String>{..._candidateNames};
      final titles = <int, String>{..._vacancyTitles};
      for (final id in candIds.where((i) => !names.containsKey(i))) {
        try {
          final c = await api.get('/candidates/$id');
          names[id] = (c as Map)['full_name'] as String? ?? '—';
        } catch (_) {
          names[id] = 'Кандидат удалён';
        }
      }
      for (final id in vacIds.where((i) => !titles.containsKey(i))) {
        try {
          final v = await api.get('/vacancies/$id');
          titles[id] = (v as Map)['title'] as String? ?? '—';
        } catch (_) {
          titles[id] = 'Вакансия удалена';
        }
      }
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _candidateNames.addAll(names);
        _vacancyTitles.addAll(titles);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _move(ApplicationItem app, String toStatus) async {
    if (app.status == toStatus) return;
    final ok = await runGuarded(context, () async {
      await AppScope.read(context)
          .api
          .patch('/applications/${app.id}', {'status': toStatus});
    });
    if (ok && mounted) {
      showInfo(context,
          '${_candidateNames[app.candidateId] ?? 'Кандидат'} → «${ApplicationItem.statusLabels[toStatus]}»');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = AppScope.read(context).user?.canManage ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vacancyId == null
            ? 'Воронка найма'
            : 'Отклики на вакансию'),
        actions: [
          GlassIconButton(Glyph.refresh, tooltip: 'Обновить', onPressed: _load),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _items.isEmpty
              ? const Center(child: Text('Откликов пока нет'))
              : LayoutBuilder(builder: (context, cons) {
                  final colWidth = cons.maxWidth < 760
                      ? cons.maxWidth * 0.82
                      : (cons.maxWidth - 32) / _columns.length;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final st in _columns)
                          SizedBox(
                            width: colWidth + 8,
                            child: _buildColumn(st, colWidth, canManage),
                          ),
                      ],
                    ),
                  );
                }),
    );
  }

  Widget _buildColumn(String statusKey, double width, bool canManage) {
    final cards = _items.where((a) => a.status == statusKey).toList();
    final color = statusColor(statusKey);
    Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              Container(
                  width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${ApplicationItem.statusLabels[statusKey]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text('${cards.length}', style: TextStyle(color: Colors.white.withOpacity(0.6))),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              for (final a in cards)
                Draggable<int>(
                  data: a.id,
                  enabled: canManage && !_dragging,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(width: width - 16, child: _card(a, preview: true)),
                  ),
                  childWhenDragging: Opacity(opacity: 0.35, child: _card(a)),
                  child: _card(a),
                ),
            ],
          ),
        ),
      ],
    );
    if (!canManage) return column;
    return DragTarget<int>(
      onDragStart: (_) => setState(() => _dragging = true),
      onDragEnd: (_) => setState(() => _dragging = false),
      onAcceptWithDetails: (details) {
        final app = _items.firstWhere((a) => a.id == details.data);
        _move(app, statusKey);
      },
      builder: (context, accepted, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: kGlassRadius,
          border: Border.all(
              color: accepted.isNotEmpty
                  ? color.withOpacity(0.9)
                  : Colors.transparent,
              width: 2),
        ),
        child: column,
      ),
    );
  }

  Widget _card(ApplicationItem a, {bool preview = false}) {
    final name = _candidateNames[a.candidateId] ?? '…';
    final vacancy = _vacancyTitles[a.vacancyId] ?? '…';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: GlassListCard(
        onTap: preview
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CandidateDetailScreen(candidateId: a.candidateId)),
                ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: kAccentColor.withOpacity(0.3),
                    child: Text(name.characters.first.toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const GlassIcon(Glyph.briefcase, size: 14),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(vacancy,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: Colors.white.withOpacity(0.65))),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(_fmtDate(a.createdAt),
                  style:
                      TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
