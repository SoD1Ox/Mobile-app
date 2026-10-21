/// Project list + create/edit/delete (manager/admin) with search & pagination.
library;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'tasks_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<ProjectItem> _items = [];
  List<ClientItem> _clients = [];
  int _page = 1;
  int _pages = 1;
  String _search = '';
  bool _loading = true;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    setState(() => _loading = true);
    final api = AppScope.of(context).api;
    try {
      final raw = await api.get('/projects', {
        'page': page ?? _page,
        'page_size': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
      });
      final p = DataPage.fromJson(raw, ProjectItem.fromJson);
      setState(() {
        _items = p.items;
        _page = p.page;
        _pages = p.pages;
        _loading = false;
      });
      if (_clients.isEmpty) {
        final craw = await api.get('/clients', {'page_size': 200});
        setState(() =>
            _clients = DataPage.fromJson(craw, ClientItem.fromJson).items);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openForm({ProjectItem? existing}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => _ProjectFormScreen(existing: existing, clients: _clients)),
    );
    if (changed == true) _load(page: 1);
  }

  Future<void> _delete(ProjectItem p) async {
    final yes = await confirmDialog(context, 'Удалить проект?',
        '«${p.name}» и все его задачи будут удалены.');
    if (!yes) return;
    final ok = await runGuarded(
        context, () => AppScope.of(context).api.delete('/projects/${p.id}'));
    if (ok) _load(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    final canManage = user?.canManage ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Проекты'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              hintText: 'Поиск проектов…',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onSubmitted: (v) {
                _search = v.trim();
                _load(page: 1);
              },
            ),
          ),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Проект'))
          : null,
      body: _loading
          ? const LoadingView()
          : Column(
              children: [
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('Проекты не найдены'))
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final p = _items[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: ListTile(
                                title: Text(p.name),
                                subtitle: Text(
                                    'Клиент #${p.clientId} · бюджет ${_fmtMoney(p.budget)} ₽'),
                                trailing: Wrap(spacing: 4, children: [
                                  if (canManage)
                                    IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _openForm(existing: p)),
                                  if (canManage)
                                    IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        onPressed: () => _delete(p)),
                                  IconButton(
                                      icon: const Icon(Icons.list_alt),
                                      tooltip: 'Задачи проекта',
                                      onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const TasksScreen()))),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
                _Pager(
                    page: _page,
                    pages: _pages,
                    onChanged: (v) => _load(page: v)),
              ],
            ),
    );
  }

  static String _fmtMoney(num v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _Pager extends StatelessWidget {
  final int page;
  final int pages;
  final ValueChanged<int> onChanged;

  const _Pager(
      {required this.page, required this.pages, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (pages <= 1) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: page > 1 ? () => onChanged(page - 1) : null),
          Text('Стр. $page из $pages'),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: page < pages ? () => onChanged(page + 1) : null),
        ],
      ),
    );
  }
}

class _ProjectFormScreen extends StatefulWidget {
  final ProjectItem? existing;
  final List<ClientItem> clients;

  const _ProjectFormScreen({this.existing, required this.clients});

  @override
  State<_ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<_ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _budget =
      TextEditingController(text: '${widget.existing?.budget ?? 0}');
  int? _clientId = widget.existing?.clientId;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      showError(context, ApiException(0, 'Выберите клиента'));
      return;
    }
    setState(() => _saving = true);
    final api = AppScope.of(context).api;
    final body = {
      'name': _name.text.trim(),
      'description':
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      'budget': _budget.text.isEmpty ? '0' : _budget.text,
      'client_id': _clientId,
    };
    final ok = await runGuarded(context, () async {
      if (_isEdit) {
        await api.put('/projects/${widget.existing!.id}', body);
      } else {
        await api.post('/projects', body);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      showInfo(context, _isEdit ? 'Проект обновлён' : 'Проект создан');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(_isEdit ? 'Редактирование проекта' : 'Новый проект')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _name,
              label: 'Название *',
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Минимум 2 символа'
                  : null,
            ),
            AppTextField(controller: _description, label: 'Описание', maxLines: 4),
            AppTextField(
                controller: _budget,
                label: 'Бюджет, ₽',
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _clientId,
              decoration: const InputDecoration(
                  labelText: 'Клиент *', border: OutlineInputBorder()),
              items: [
                for (final c in widget.clients)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _clientId = v),
              validator: (v) => v == null ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Сохранить' : 'Создать'),
            ),
          ],
        ),
      ),
    );
  }
}
