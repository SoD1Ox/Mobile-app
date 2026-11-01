/// Candidate card: contacts, applications history and recruiter notes.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/glass.dart';
import '../theme/glass_stack.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';
import 'candidate_form_screen.dart';

class CandidateDetailScreen extends StatefulWidget {
  final int candidateId;
  const CandidateDetailScreen({super.key, required this.candidateId});

  @override
  State<CandidateDetailScreen> createState() => _CandidateDetailScreenState();
}

class _CandidateDetailScreenState extends State<CandidateDetailScreen> {
  CandidateItem? _candidate;
  List<ApplicationItem> _applications = [];
  List<CommentItem> _comments = [];
  final Map<int, String> _vacancyTitles = {};
  final _noteController = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = AppScope.read(context).api;
      final results = await Future.wait([
        api.get('/candidates/${widget.candidateId}'),
        api.get('/applications',
            {'candidate_id': widget.candidateId, 'page_size': 100}),
        api.get('/candidates/${widget.candidateId}/comments'),
      ]);
      final c =
          CandidateItem.fromJson(Map<String, dynamic>.from(results[0] as Map));
      final apps = DataPage.fromJson(results[1], ApplicationItem.fromJson).items;
      final comments = (results[2] as List)
          .map((e) => CommentItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // Resolve vacancy titles for the pipeline list (small N, cached).
      final titles = <int, String>{..._vacancyTitles};
      for (final a in apps) {
        if (!titles.containsKey(a.vacancyId)) {
          try {
            final v = await api.get('/vacancies/${a.vacancyId}');
            titles[a.vacancyId] = (v as Map)['title'] as String? ?? '—';
          } catch (_) {
            titles[a.vacancyId] = 'Вакансия удалена';
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _candidate = c;
        _applications = apps;
        _comments = comments;
        _vacancyTitles.addAll(titles);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _delete() async {
    final yes = await confirmDialog(context, 'Удалить кандидата?',
        'Все его отклики и заметки будут удалены.');
    if (!yes || !mounted) return;
    final ok = await runGuarded(
        context, () => AppScope.read(context).api.delete('/candidates/${widget.candidateId}'));
    if (ok && mounted) Navigator.pop(context, true);
  }

  Future<void> _addNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final ok = await runGuarded(context, () async {
      await AppScope.read(context).api.post(
          '/candidates/${widget.candidateId}/comments', {'text': text});
    });
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _noteController.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.read(context).user;
    final c = _candidate;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.fullName ?? 'Кандидат'),
        actions: [
          if (c != null && (user?.canManage ?? false))
            GlassIconButton(Glyph.edit,
                onPressed: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CandidateFormScreen(existing: c)),
                  );
                  if (changed == true) _load();
                }),
          if (c != null && (user?.isAdmin ?? false))
            GlassIconButton(Glyph.delete, onPressed: _delete),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : c == null
              ? const Center(child: Text('Кандидат не найден'))
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    RealGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: kAccentColor.withOpacity(0.3),
                                child: Text(c.fullName.characters.first.toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 22, fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.fullName,
                                        style: const TextStyle(
                                            fontSize: 19, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${c.specialization ?? 'Без специализации'} · ${c.expLabel}',
                                        style: TextStyle(
                                            color: Colors.white.withOpacity(0.75))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (c.email != null) _row(Glyph.mail, c.email!),
                          if (c.phone != null) _row(Glyph.phone, c.phone!),
                          if (c.city != null) _row(Glyph.pin, c.city!),
                          if (c.resumeUrl != null) _row(Glyph.resume, c.resumeUrl!),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassListCard(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Отклики (${_applications.length})',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            if (_applications.isEmpty)
                              Text('Пока нет откликов',
                                  style: TextStyle(color: Colors.white.withOpacity(0.5)))
                            else
                              for (final a in _applications)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                            _vacancyTitles[a.vacancyId] ?? '…',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      StatusChip(
                                          label: a.statusLabel,
                                          color: statusColor(a.status)),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassListCard(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Заметки рекрутеров (${_comments.length})',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            for (final cm in _comments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cm.text, style: const TextStyle(height: 1.4)),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${cm.authorName ?? 'Сотрудник'} · ${_fmtDate(cm.createdAt)}',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.white.withOpacity(0.45))),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _noteController,
                                    minLines: 1,
                                    maxLines: 3,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                        hintText: 'Новая заметка…'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GlassIconButton(Glyph.send,
                                    size: 20,
                                    onPressed: _sending ? null : _addNote),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Widget _row(Glyph g, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            GlassIcon(g, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: SelectableText(text,
                    style: TextStyle(color: Colors.white.withOpacity(0.85)))),
          ],
        ),
      );
}
