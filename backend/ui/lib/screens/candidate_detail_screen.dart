/// Candidate card: contact info, hiring history (applications) and the
/// recruiter comment thread (GET/POST /candidates/{id}/comments).
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
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
  final _commentController = TextEditingController();

  CandidateItem? _candidate;
  List<CommentItem> _comments = [];
  List<ApplicationItem> _applications = [];
  Map<int, String> _vacancyTitles = {};
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.read(context).api;
    try {
      final c = await api.get('/candidates/${widget.candidateId}')
          as Map<String, dynamic>;
      final commentsRaw =
          await api.get('/candidates/${widget.candidateId}/comments');
      final appsRaw =
          await api.get('/applications', {'candidate_id': c['id'], 'page_size': 100});
      final apps = DataPage.fromJson(appsRaw as Map<String, dynamic>, ApplicationItem.fromJson)
          .items;
      // Resolve vacancy titles for the history list (small N — sequential is fine).
      final titles = <int, String>{};
      for (final a in apps.toSet().map((e) => e.vacancyId)) {
        try {
          final v = await api.get('/vacancies/$a') as Map<String, dynamic>;
          titles[a] = v['title'] as String;
        } catch (_) {
          titles[a] = 'Вакансия #$a';
        }
      }
      if (!mounted) return;
      setState(() {
        _candidate = CandidateItem.fromJson(c);
        _comments = ((commentsRaw as List?) ?? [])
            .map((e) => CommentItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _applications = apps;
        _vacancyTitles = titles;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final api = AppScope.read(context).api;
    setState(() => _sending = true);
    try {
      await api.post('/candidates/${widget.candidateId}/comments',
          {'text': text, 'candidate_id': widget.candidateId});
      _commentController.clear();
      FocusScope.of(context).unfocus();
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => CandidateFormScreen(existing: _candidate)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
        context,
        'Удалить кандидата?',
        'Карточка «${_candidate!.fullName}», её комментарии и отклики будут удалены.');
    if (!ok) return;
    final api = AppScope.read(context).api;
    final done =
        await runGuarded(context, () => api.delete('/candidates/${widget.candidateId}'));
    if (done && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());
    final c = _candidate!;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.fullName, overflow: TextOverflow.ellipsis),
        actions: [
          GlassIconButton(Glyph.edit, onPressed: _edit, tooltip: 'Редактировать'),
          GlassIconButton(Glyph.delete, onPressed: _delete, tooltip: 'Удалить'),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          RealGlassCard(
            blur: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.fullName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  '${c.specialization ?? 'Без специализации'} · ${c.expLabel}'
                  '${c.city != null ? ' · ${c.city}' : ''}',
                  style: TextStyle(color: Colors.white.withOpacity(0.75)),
                ),
                const SizedBox(height: 12),
                _row(Glyph.mail, c.email ?? 'Email не указан'),
                _row(Glyph.phone, c.phone ?? 'Телефон не указан'),
                if (c.resumeUrl != null && c.resumeUrl!.isNotEmpty)
                  _row(Glyph.resume, c.resumeUrl!),
                _row(Glyph.person, 'В базе с ${_fmtDate(c.createdAt)}'),
              ],
            ),
          ),
          RealGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('История откликов',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (_applications.isEmpty)
                  Text('Кандидат ещё не откликался на вакансии.',
                      style: TextStyle(color: Colors.white.withOpacity(0.6))),
                for (final a in _applications)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _vacancyTitles[a.vacancyId] ?? 'Вакансия #${a.vacancyId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(
                            label: a.statusLabel, color: statusColor(a.status)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          RealGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Заметки рекрутеров',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (_comments.isEmpty)
                  Text('Пока нет заметок по кандидату.',
                      style: TextStyle(color: Colors.white.withOpacity(0.6))),
                for (final cm in _comments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cm.text, style: const TextStyle(height: 1.35)),
                        const SizedBox(height: 2),
                        Text(
                          '${cm.authorName ?? 'Рекрутер'} · ${_fmtDate(cm.createdAt)}',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withOpacity(0.45)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Добавить заметку…',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : GlassIconButton(Glyph.send,
                            onPressed: _sendComment, tooltip: 'Отправить'),
                  ],
                ),
              ],
            ),
          ),
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

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
