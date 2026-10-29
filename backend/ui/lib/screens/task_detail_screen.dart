/// Single-task view: full data, status quick-changes, edit/delete and comments.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TaskItem? _task;
  List<CommentItem> _comments = [];
  final _commentText = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentText.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    try {
      final results = await Future.wait([
        api.get('/tasks/${widget.taskId}'),
        api.get('/tasks/${widget.taskId}/comments'),
      ]);
      if (!mounted) return;
      setState(() {
        _task = TaskItem.fromJson(results[0]);
        _comments =
            (results[1] as List).map((e) => CommentItem.fromJson(e)).toList();
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _changeStatus(String status) async {
    setState(() => _busy = true);
    final ok = await runGuarded(context, () async {
      await AppScope.of(context)
          .api
          .put('/tasks/${widget.taskId}', {'status': status});
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      showInfo(context, 'Статус обновлён');
      _load();
    }
  }

  Future<void> _addComment() async {
    final text = _commentText.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    final ok = await runGuarded(context, () async {
      await AppScope.of(context).api.post(
          '/tasks/${widget.taskId}/comments',
          {'text': text, 'task_id': widget.taskId});
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _commentText.clear();
      _load();
    }
  }

  Future<void> _deleteComment(CommentItem c) async {
    final yes = await confirmDialog(
        context, 'Удалить комментарий?', 'Действие необратимо.');
    if (!yes) return;
        if (!mounted) return;
    // ignore: use_build_context_synchronously
    final api = AppScope.of(context).api;
    final ok = await runGuarded(context, () async {
      await api.delete('/tasks/comments/${c.id}');
    });
    if (ok) _load();
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskFormScreen(existing: _task)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete() async {
    final yes = await confirmDialog(
        context, 'Удалить задачу?', '«${_task!.title}» будет удалена навсегда.');
    if (!yes) return;
        if (!mounted) return;
    // ignore: use_build_context_synchronously
    final api = AppScope.of(context).api;
    final ok = await runGuarded(context, () async {
      await api.delete('/tasks/${widget.taskId}');
    });
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final user = scope.user;
    final t = _task;
    if (t == null) return const Scaffold(body: LoadingView());

    final canEdit = user?.canManage ?? false || user?.id == t.authorId;
    final canDelete = user?.canManage ?? false || user?.id == t.authorId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Задача #${t.id}'),
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const GlassIcon(Glyph.back, size: 20)),
        actions: [
          if (canEdit)
            GlassIconButton(Glyph.edit, tooltip: 'Редактировать', onPressed: _edit),
          if (canDelete)
            GlassIconButton(Glyph.delete,
                tooltip: 'Удалить',
                color: const Color(0xFFFF7A7A),
                onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusChip(label: t.statusLabel, color: statusColor(t.status)),
              StatusChip(
                  label: t.priorityLabel, color: priorityColor(t.priority)),
              Chip(label: Text('~${t.estimateHours} ч')),
              for (final tag in t.tags)
                Chip(
                    label: Text('#${tag.name}'),
                    visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 12),
          if (t.description != null && t.description!.isNotEmpty) ...[
            Text('Описание',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(t.description!),
            const SizedBox(height: 8),
          ],
          Text('Автор: #${t.authorId} · Проект: #${t.projectId}',
              style: TextStyle(color: Colors.white.withOpacity(0.55))),
          Text('Создана: ${_fmt(t.createdAt)}   Обновлена: ${_fmt(t.updatedAt)}',
              style: TextStyle(color: Colors.white.withOpacity(0.55))),
          const SizedBox(height: 16),
          if (user?.canManage ?? false) ...[
            Text('Сменить статус',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final e in TaskItem.statusLabels.entries)
                  OutlinedButton(
                    onPressed:
                        _busy || e.key == t.status ? null : () => _changeStatus(e.key),
                    child: Text(e.value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const Divider(),
          Text('Комментарии (${_comments.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final c in _comments)
            GlassListCard(
              child: ListTile(
                title: Text(c.text),
                subtitle: Text('Автор #${c.authorId} · ${_fmt(c.createdAt)}'),
                trailing: (user?.canManage ?? false)
                    ? GlassIconButton(Glyph.delete,
                        size: 19,
                        tooltip: 'Удалить комментарий',
                        color: const Color(0xFFFF7A7A),
                        onPressed: () => _deleteComment(c))
                    : null,
              ),
            ),
          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Комментариев пока нет',
                  style: TextStyle(color: Colors.white.withOpacity(0.55))),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentText,
                  decoration:
                    const InputDecoration(labelText: 'Новый комментарий'),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: _busy ? null : _addComment,
                  child: const GlassIcon(Glyph.send, size: 20)),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
