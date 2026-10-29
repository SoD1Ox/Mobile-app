/// Client list + CRUD (manager/admin) and nested contact persons.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<ClientItem> _items = [];
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
    try {
      final raw = await AppScope.read(context).api.get('/clients', {
        'page': page ?? _page,
        'page_size': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
      });
      final p = DataPage.fromJson(raw, ClientItem.fromJson);
      if (!mounted) return;
      setState(() {
        _items = p.items;
        _page = p.page;
        _pages = p.pages;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openForm({ClientItem? existing}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _ClientFormScreen(existing: existing)),
    );
    if (changed == true) _load(page: 1);
  }

  Future<void> _delete(ClientItem c) async {
    final yes = await confirmDialog(
        context, 'Удалить клиента?', '«${c.name}» будет удалён навсегда.');
    if (!yes) return;
    // ignore: use_build_context_synchronously
    final api = AppScope.read(context).api;
    final ok = await runGuarded(context, () => api.delete('/clients/${c.id}'));
    if (ok) _load(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final canManage = AppScope.read(context).user?.canManage ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Клиенты'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              hintText: 'Поиск по названию…',
              leading: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: GlassIcon(Glyph.search, size: 20)),
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
              icon: const GlassIcon(Glyph.add, size: 20),
              label: const Text('Клиент'))
          : null,
      body: _loading
          ? const LoadingView()
          : Column(
              children: [
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('Клиенты не найдены'))
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final c = _items[i];
                            return GlassListCard(
                              child: ListTile(
                                leading: CircleAvatar(
                                    child: Text(c.name.characters.first.toUpperCase())),
                                title: Text(c.name),
                                subtitle: Text(
                                    [c.email, c.phone]
                                        .where((e) => e != null && e.isNotEmpty)
                                        .join(' · ')),
                                trailing: Wrap(
                                    spacing: 4,
                                    children: <Widget>[
                                      GlassIconButton(Glyph.people,
                                          tooltip: 'Контактные лица',
                                          onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      ContactsScreen(client: c))),
                                      ),
                                      if (canManage)
                                        GlassIconButton(Glyph.edit,
                                            tooltip: 'Редактировать',
                                            onPressed: () => _openForm(existing: c)),
                                      if (canManage)
                                        GlassIconButton(Glyph.delete,
                                            tooltip: 'Удалить',
                                            color: const Color(0xFFFF7A7A),
                                            onPressed: () => _delete(c)),
                                    ]),
                              ),
                            );
                          },
                        ),
                ),
                if (_pages > 1)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GlassIconButton(Glyph.chevronLeft,
                            onPressed: _page > 1 ? () => _load(page: _page - 1) : null),
                        Text('Стр. $_page из $_pages'),
                        GlassIconButton(Glyph.chevronRight,
                            onPressed:
                                _page < _pages ? () => _load(page: _page + 1) : null),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Contact persons of one client (nested entity).
class ContactsScreen extends StatefulWidget {
  final ClientItem client;

  const ContactsScreen({super.key, required this.client});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<ContactItem> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await AppScope.read(context)
          .api
          .get('/clients/${widget.client.id}/contacts');
      if (!mounted) return;
      setState(() {
        _contacts =
            (raw as List).map((e) => ContactItem.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openForm({ContactItem? existing}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => _ContactFormScreen(
              clientId: widget.client.id, existing: existing)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(ContactItem c) async {
    final yes = await confirmDialog(
        context, 'Удалить контакт?', '«${c.fullName}» будет удалён.');
    if (!yes) return;
    // ignore: use_build_context_synchronously
    final api = AppScope.read(context).api;
    final ok = await runGuarded(context, () => api.delete('/clients/contacts/${c.id}'));
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = AppScope.read(context).user?.canManage ?? false;
    return Scaffold(
      appBar: AppBar(title: Text('Контакты: ${widget.client.name}')),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              child: const GlassIcon(Glyph.plusCircle, size: 24))
          : null,
      body: _loading
          ? const LoadingView()
          : _contacts.isEmpty
              ? const Center(child: Text('Контактных лиц нет'))
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (_, i) {
                    final c = _contacts[i];
                    return GlassListCard(
                      child: ListTile(
                        title: Text(c.fullName),
                        subtitle: Text([
                          if (c.position != null) c.position!,
                          if (c.email != null) c.email!,
                          if (c.phone != null) c.phone!,
                        ].join(' · ')),
                        trailing: canManage
                            ? Wrap(spacing: 4, children: [
                                GlassIconButton(Glyph.edit,
                                    tooltip: 'Редактировать',
                                    onPressed: () => _openForm(existing: c)),
                                GlassIconButton(Glyph.delete,
                                    tooltip: 'Удалить',
                                    color: const Color(0xFFFF7A7A),
                                    onPressed: () => _delete(c)),
                              ])
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}

class _ClientFormScreen extends StatefulWidget {
  final ClientItem? existing;

  const _ClientFormScreen({this.existing});

  @override
  State<_ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<_ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _address =
      TextEditingController(text: widget.existing?.address ?? '');
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _body() => {
        'name': _name.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
      if (!mounted) return;
    // ignore: use_build_context_synchronously
    final api = AppScope.read(context).api;
    final ok = await runGuarded(context, () async {
      if (_isEdit) {
        await api.put('/clients/${widget.existing!.id}', _body());
      } else {
        await api.post('/clients', _body());
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      showInfo(context, _isEdit ? 'Клиент обновлён' : 'Клиент создан');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(_isEdit ? 'Редактирование клиента' : 'Новый клиент')),
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
                      : null),
              AppTextField(
                  controller: _email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress),
              AppTextField(controller: _phone, label: 'Телефон'),
              AppTextField(controller: _address, label: 'Адрес'),
              const SizedBox(height: 24),
              FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const GlassIcon(Glyph.save, size: 19),
                  label: Text(_isEdit ? 'Сохранить' : 'Создать')),
            ],
          ),
        ),
      );
}

class _ContactFormScreen extends StatefulWidget {
  final int clientId;
  final ContactItem? existing;

  const _ContactFormScreen({required this.clientId, this.existing});

  @override
  State<_ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<_ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _fullName =
      TextEditingController(text: widget.existing?.fullName ?? '');
  late final _position =
      TextEditingController(text: widget.existing?.position ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_fullName, _position, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = AppScope.read(context).api;
    final body = {
      'full_name': _fullName.text.trim(),
      'position': _position.text.trim().isEmpty ? null : _position.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'client_id': widget.clientId,
    };
    final ok = await runGuarded(context, () async {
      if (_isEdit) {
        await api.put('/clients/contacts/${widget.existing!.id}', body);
      } else {
        await api.post('/clients/${widget.clientId}/contacts', body);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      showInfo(context, _isEdit ? 'Контакт обновлён' : 'Контакт создан');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(_isEdit ? 'Редактирование контакта' : 'Новый контакт')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppTextField(
                  controller: _fullName,
                  label: 'ФИО *',
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Минимум 2 символа'
                      : null),
              AppTextField(controller: _position, label: 'Должность'),
              AppTextField(
                  controller: _email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress),
              AppTextField(controller: _phone, label: 'Телефон'),
              const SizedBox(height: 24),
              FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const GlassIcon(Glyph.save, size: 19),
                  label: Text(_isEdit ? 'Сохранить' : 'Создать')),
            ],
          ),
        ),
      );
}
