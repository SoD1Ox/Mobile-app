/// Hiring pipeline board (kanban): applications grouped by stage.
/// Managers/admins drag cards between columns — each drop is a PATCH to the
/// API, so moving a card is a real server operation with error feedback.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/glass.dart';
import '../theme/glass_stack.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';
import 'candidate_detail_screen.dart';

class ApplicationsScreen extends StatefulWidget {
  final int? vacancyId; // null => all vacancies
  final bool mineOnly; // worker queue: only applications assigned to me
  const ApplicationsScreen({super.key, this.vacancyId, this.mineOnly = false});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  List<ApplicationItem> _items = [];
  final Map<int, String> _candidateNames = {};
  final Map<int, String> _vacancyTitles = {};
  bool _loading = true;

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
        if (widget.mineOnly) 'mine': true,
      });
      final page = DataPage.fromJson(raw, ApplicationItem.fromJson);
      // The server now ships candidate/vacancy names inside each application
      // (denormalized DTO) — no per-card requests. Fallback batch fetch by ids
      // covers legacy rows without the embedded fields.
      final names = <int, String>{..._candidateNames};
      final titles = <int, String>{..._vacancyTitles};
      for (final a in page.items) {
        if (a.candidateName != null) names[a.candidateId] = a.candidateName!;
        if (a.vacancyTitle != null) titles[a.vacancyId] = a.vacancyTitle!;
      }
      final missingCand = page.items
          .map((e) => e.candidateId)
          .toSet()
          .where((i) => !names.containsKey(i))
          .toList();
      final missingVac = page.items
          .map((e) => e.vacancyId)
          .toSet()
          .where((i) => !titles.containsKey(i))
          .toList();
      if (missingCand.isNotEmpty) {
        try {
          final res = await api.get('/candidates',
              {'ids': missingCand.join(','), 'page_size': missingCand.length});
          final items = (res is Map && res['items'] is List)
              ? res['items'] as List
              : const [];
          for (final e in items.whereType<Map>()) {
            final m = Map<String, dynamic>.from(e);
            names[(m['id'] as num?)?.toInt() ?? 0] =
                m['full_name'] as String? ?? '—';
          }
        } catch (_) {/* leave unknown */}
      }
      if (missingVac.isNotEmpty) {
        try {
          final res = await api.get('/vacancies',
              {'ids': missingVac.join(','), 'page_size': missingVac.length});
          final items = (res is Map && res['items'] is List)
              ? res['items'] as List
              : const [];
          for (final e in items.whereType<Map>()) {
            final m = Map<String, dynamic>.from(e);
            titles[(m['id'] as num?)?.toInt() ?? 0] =
                m['title'] as String? ?? '—';
          }
        } catch (_) {}
      }
      for (final id in missingCand.where((i) => !names.containsKey(i))) {
        names[id] = 'Кандидат удалён';
      }
      for (final id in missingVac.where((i) => !titles.containsKey(i))) {
        titles[id] = 'Вакансия удалена';
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
      AppScope.read(context).notifications.add(
            'Этап отклика изменён',
            '${_candidateNames[app.candidateId] ?? 'Кандидат'} · ${app.vacancyTitle ?? 'Вакансия'} · ${ApplicationItem.statusLabels[toStatus]}',
          );
      showInfo(context,
          '${_candidateNames[app.candidateId] ?? 'Кандидат'} → «${ApplicationItem.statusLabels[toStatus]}»');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.read(context).user;
    // Иерархия drag-n-drop: менеджер/админ тасают всю воронку; worker —
    // только карточки, назначенные лично ему (бэкенд это же и проверяет).
    final canDrag = (user?.canManage ?? false) ||
        (user?.role == 'worker' && widget.mineOnly);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mineOnly
            ? 'Мои кейсы'
            : widget.vacancyId == null
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final st in _columns)
                          SizedBox(
                            width: colWidth + 8,
                            child: _buildColumn(st, colWidth, canDrag),
                          ),
                      ],
                    ),
                  );
                }),
    );
  }

  Widget _buildColumn(String statusKey, double width, bool canDrag) {
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
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${ApplicationItem.statusLabels[statusKey]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text('${cards.length}',
                  style: TextStyle(color: appTextColor(context, opacity: 0.7))),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final app = cards[index];
              if (!canDrag) return _card(app);
              return Draggable<int>(
                data: app.id,
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                      width: width - 16, child: _card(app, preview: true)),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: _card(app)),
                child: _card(app),
              );
            },
          ),
        ),
      ],
    );
    if (!canDrag) return column;
    return DragTarget<int>(
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
        onTap: preview ? null : () => _showTimeline(a),
        onLongPress: preview
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          CandidateDetailScreen(candidateId: a.candidateId)),
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
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
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
                            fontSize: 12,
                            color: appTextColor(context, opacity: 0.72))),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(_fmtDate(a.createdAt),
                        style: TextStyle(
                            fontSize: 11,
                            color: appTextColor(context, opacity: 0.62))),
                  ),
                  if (a.completionScore != null && a.completionScore! > 0) ...[
                    const GlassIcon(Glyph.chart, size: 13),
                    const SizedBox(width: 4),
                    Text('${(a.completionScore! * 100).round()}%',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kAccentColor)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom sheet with the full audit timeline of one application.
  void _showTimeline(ApplicationItem a) {
    final tl = a.timeline;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: GlassPanel(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('История кейса · ${_candidateNames[a.candidateId] ?? ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(a.vacancyTitle ?? '',
                    style: TextStyle(
                        fontSize: 12,
                        color: appTextColor(context, opacity: 0.72))),
                const SizedBox(height: 12),
                if (tl.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Перемещений статуса ещё не было.',
                        style: TextStyle(
                            color: appTextColor(context, opacity: 0.7))),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: tl.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final (from, to, stamp) = tl[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GlassIcon(Glyph.dot,
                                size: 10, color: kAccentColor.withOpacity(0.9)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$from → $to',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                  if (stamp.isNotEmpty)
                                    Text(stamp,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: appTextColor(context,
                                                opacity: 0.62))),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
