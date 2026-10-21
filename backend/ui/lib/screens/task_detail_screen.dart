/// Single-task view: full data, status quick-changes, edit/delete and comments.
library;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
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
          '/tasks/${widget.taskId}/comments', {'text': text});
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
    final ok = await runGuarded(context, () async {
      await AppScope.of(context).api.delete('/tasks/comments/${c.id}');
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
    final ok = await runGuarded(context, () async {
      await AppScope.of(context).api.delete('/tasks/${widget.taskId}');
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
        actions: [
          if (canEdit)
            IconButton(
                icon: const Icon(Icons.edit_outlined), onPressed: _edit),
          if (canDelete)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
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
          Text('Автор: #$authorId · Проект: #$projectId',
              style: TextStyle(color: Colors.grey.shade600)),
          Text('Создана: ${_fmt(t.createdAt)}   Обновлена: ${_fmt(t.updatedAt)}',
              style: TextStyle(color: Colors.grey.shade600)),
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
          Divider(),
          Text('Комментарии (${_comments.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final c in _comments)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(c.text),
                subtitle: Text('Автор #${c.authorId} · ${_fmt(c.createdAt)}'),
                trailing: (user?.canManage ?? false)
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _deleteComment(c))
                    : null,
              ),
            ),
          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Комментариев пока нет',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentText,
                  decoration: const InputDecoration(
                      labelText: 'Новый комментарий',
                      border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                  onPressed: _busy ? null : _addComment,
                  icon: const Icon(Icons.send)),
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
