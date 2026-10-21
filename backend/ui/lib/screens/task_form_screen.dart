/// Task create / edit form.  Validates on the client, sends a DTO-shaped
/// JSON body to the API; server-side validation errors are surfaced too.
library;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class TaskFormScreen extends StatefulWidget {
  final TaskItem? existing; // null => create
  final Map<String, dynamic>? query;

  const TaskFormScreen({super.key, this.existing, this.query});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _estimate =
      TextEditingController(text: '${widget.existing?.estimateHours ?? 0}');

  late String _status = widget.existing?.status ?? 'new';
  late String _priority = widget.existing?.priority ?? 'medium';

  List<ProjectItem> _projects = [];
  List<TagItem> _tags = [];
  int? _projectId;
  final Set<int> _selectedTagIds = {};

  bool _loadingRefs = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _projectId = widget.existing?.projectId;
    for (final t in widget.existing?.tags ?? <TagItem>[]) {
      _selectedTagIds.add(t.id);
    }
    _loadRefs();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _estimate.dispose();
    super.dispose();
  }

  Future<void> _loadRefs() async {
    final api = AppScope.of(context).api;
    try {
      final results = await Future.wait([
        api.get('/projects', {'page_size': 200}),
        api.get('/tags'),
      ]);
      setState(() {
        _projects = DataPage.fromJson(results[0], ProjectItem.fromJson).items;
        _tags = (results[1] as List).map((e) => TagItem.fromJson(e)).toList();
        _loadingRefs = false;
      });
    } catch (e) {
      if (mounted) showError(context, e);
      setState(() => _loadingRefs = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_projectId == null) {
      showError(context, ApiException(0, 'Выберите проект'));
      return;
    }
    setState(() => _saving = true);
    final api = AppScope.of(context).api;
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'description':
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      'status': _status,
      'priority': _priority,
      'estimate_hours': int.parse(_estimate.text.isEmpty ? '0' : _estimate.text),
      'project_id': _projectId,
      'tag_ids': _selectedTagIds.toList(),
    };
    final ok = await runGuarded(context, () async {
      if (_isEdit) {
        await api.put('/tasks/${widget.existing!.id}', body);
      } else {
        await api.post('/tasks', body);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      showInfo(context, _isEdit ? 'Задача обновлена' : 'Задача создана');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактирование задачи' : 'Новая задача'),
      ),
      body: _loadingRefs
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppTextField(
                    controller: _title,
                    label: 'Название *',
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Минимум 2 символа'
                        : null,
                  ),
                  AppTextField(
                    controller: _description,
                    label: 'Описание',
                    maxLines: 5,
                  ),
                  if (_projects.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: _projectId,
                      decoration: const InputDecoration(
                          labelText: 'Проект *', border: OutlineInputBorder()),
                      items: [
                        for (final p in _projects)
                          DropdownMenuItem(value: p.id, child: Text(p.name)),
                      ],
                      onChanged: (v) => setState(() => _projectId = v),
                      validator: (v) => v == null ? 'Обязательное поле' : null,
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                        labelText: 'Статус', border: OutlineInputBorder()),
                    items: [
                      for (final e in TaskItem.statusLabels.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: const InputDecoration(
                        labelText: 'Приоритет', border: OutlineInputBorder()),
                    items: [
                      for (final e in TaskItem.priorityLabels.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _priority = v!),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _estimate,
                    label: 'Оценка, часов',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final n = int.tryParse(v);
                      return (n == null || n < 0 || n > 10000)
                          ? 'Число от 0 до 10000'
                          : null;
                    },
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Теги', style: Theme.of(context).textTheme.titleMedium),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final t in _tags)
                          FilterChip(
                            label: Text(t.name),
                            selected: _selectedTagIds.contains(t.id),
                            onSelected: (sel) => setState(() {
                              if (sel) {
                                _selectedTagIds.add(t.id);
                              } else {
                                _selectedTagIds.remove(t.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(_isEdit ? 'Сохранить изменения' : 'Создать задачу'),
                  ),
                ],
              ),
            ),
    );
  }
}
