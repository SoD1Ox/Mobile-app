/// Task list screen: paginated "load more" (large-data mechanism),
/// live search and status/priority filters.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _scrollController = ScrollController();

  List<TaskItem> _items = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;

  String _search = '';
  String? _status;
  String? _priority;

  static const _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final api = AppScope.of(context).api;
      final next = reset ? 1 : _page + 1;
      final raw = await api.get('/tasks', {
        'page': next,
        'page_size': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
        if (_status != null) 'status': _status,
        if (_priority != null) 'priority': _priority,
      });
      final page = DataPage.fromJson(raw, TaskItem.fromJson);
      setState(() {
        if (reset) {
          _items = page.items;
        } else {
          _items = [..._items, ...page.items];
        }
        _page = next;
        _total = page.total;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _filtersAsQuery() => {
        if (_search.isNotEmpty) 'search': _search,
        if (_status != null) 'status': _status,
        if (_priority != null) 'priority': _priority,
      };

  Future<void> _openForm({TaskItem? task}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => TaskFormScreen(existing: task, query: _filtersAsQuery())),
    );
    if (changed == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Задачи'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(118),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchBar(
                  hintText: 'Поиск по названию / описанию…',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onSubmitted: (v) {
                    _search = v.trim();
                    _load(reset: true);
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(_status == null
                          ? 'Все статусы'
                          : TaskItem.statusLabels[_status]!),
                      selected: _status != null,
                      onSelected: (_) => _pickStatus(),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(_priority == null
                          ? 'Любой приоритет'
                          : TaskItem.priorityLabels[_priority]!),
                      selected: _priority != null,
                      onSelected: (_) => _pickPriority(),
                    ),
                    if (_search.isNotEmpty || _status != null || _priority != null) ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.close, size: 16),
                        label: const Text('Сбросить'),
                        onPressed: () {
                          setState(() {
                            _search = '';
                            _status = null;
                            _priority = null;
                          });
                          _load(reset: true);
                        },
                      ),
                    ],
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('Всего: $_total'),
                      avatar: const Icon(Icons.storage_outlined, size: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Новая задача'),
      ),
      body: _items.isEmpty && !_loading
          ? const Center(child: Text('Задачи не найдены'))
          : RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _items.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _items.length) {
                    _load();
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final t = _items[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      title: Text(t.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusChip(
                                label: t.statusLabel, color: statusColor(t.status)),
                            StatusChip(
                                label: t.priorityLabel,
                                color: priorityColor(t.priority)),
                            if (t.tags.isNotEmpty)
                              Text('#${t.tags.map((e) => e.name).join(' #')}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                            Text('~${t.estimateHours} ч',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      trailing: user?.canManage ?? false
                          ? IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _openForm(task: t),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(taskId: t.id)),
                        );
                        if (changed == true) _load(reset: true);
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _pickStatus() async {
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Статус'),
        children: [
          for (final e in TaskItem.statusLabels.entries)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, e.key), child: Text(e.value)),
          const SimpleDialogOption(value: '', title: Text('Все')),
        ],
      ),
    );
    if (v != null) {
      setState(() => _status = v.isEmpty ? null : v);
      _load(reset: true);
    }
  }

  Future<void> _pickPriority() async {
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Приоритет'),
        children: [
          for (final e in TaskItem.priorityLabels.entries)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, e.key), child: Text(e.value)),
          const SimpleDialogOption(value: '', title: Text('Любой')),
        ],
      ),
    );
    if (v != null) {
      setState(() => _priority = v.isEmpty ? null : v);
      _load(reset: true);
    }
  }
}
