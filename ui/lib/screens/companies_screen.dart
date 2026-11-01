/// Partner companies: list + detail card with contacts (nested CRUD).
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/glass.dart';
import '../theme/glass_stack.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final _searchController = TextEditingController();
  List<CompanyItem> _items = [];
  int _total = 0;
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await AppScope.read(context).api.get('/companies', {
        'page_size': 100,
        if (_search.isNotEmpty) 'search': _search,
      });
      final page = DataPage.fromJson(raw, CompanyItem.fromJson);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _total = page.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _openForm({CompanyItem? existing}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _CompanyFormDialog(existing: existing),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.read(context).user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Компании'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Поиск по названию… ($_total)',
                prefixIcon: const GlassIcon(Glyph.search, size: 20),
              ),
              onSubmitted: (v) {
                setState(() => _search = v.trim());
                _load();
              },
            ),
          ),
        ),
      ),
      floatingActionButton: (user?.canManage ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const GlassIcon(Glyph.add, size: 20),
              label: const Text('Новая компания'),
            )
          : null,
      body: _loading
          ? const LoadingView()
          : _items.isEmpty
              ? const Center(child: Text('Компании не найдены'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final c = _items[i];
                      return GlassListCard(
                        onTap: () async {
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CompanyDetailScreen(companyId: c.id)),
                          );
                          if (changed == true) _load();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: kAccentColor.withOpacity(0.25),
                                ),
                                child: Center(
                                    child: GlassIcon(Glyph.building, size: 22)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 15.5, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 3),
                                    Text(
                                      [
                                        if ((c.industry ?? '').isNotEmpty) c.industry!,
                                        if ((c.address ?? '').isNotEmpty) c.address!,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.white.withOpacity(0.6)),
                                    ),
                                  ],
                                ),
                              ),
                              const GlassIcon(Glyph.chevronRight, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// Company card: info + vacancies count + contact persons CRUD.
class CompanyDetailScreen extends StatefulWidget {
  final int companyId;
  const CompanyDetailScreen({super.key, required this.companyId});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  CompanyItem? _company;
  List<ContactItem> _contacts = [];
  int _vacancyCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = AppScope.read(context).api;
      final results = await Future.wait([
        api.get('/companies/${widget.companyId}'),
        api.get('/companies/${widget.companyId}/contacts'),
        api.get('/vacancies', {'page_size': 1, 'company_id': widget.companyId}),
      ]);
      if (!mounted) return;
      setState(() {
        _company =
            CompanyItem.fromJson(Map<String, dynamic>.from(results[0] as Map));
        _contacts = (results[1] as List)
            .map((e) => ContactItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _vacancyCount = (results[2] as Map)['total'] as int? ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _deleteCompany() async {
    final yes = await confirmDialog(
        context, 'Удалить компанию?', 'Вакансии компании станут безработными.');
    if (!yes || !mounted) return;
    final ok = await runGuarded(context,
        () => AppScope.read(context).api.delete('/companies/${widget.companyId}'));
    if (ok && mounted) Navigator.pop(context, true);
  }

  Future<void> _openContactForm({ContactItem? existing}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ContactFormDialog(companyId: widget.companyId, existing: existing),
    );
    if (changed == true) _load();
  }

  Future<void> _deleteContact(ContactItem ct) async {
    final yes = await confirmDialog(context, 'Удалить контакт?', ct.fullName);
    if (!yes || !mounted) return;
    await runGuarded(
        context, () => AppScope.read(context).api.delete('/contacts/${ct.id}'));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.read(context).user;
    final canManage = user?.canManage ?? false;
    final c = _company;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.name ?? 'Компания'),
        actions: [
          if (c != null && canManage) ...[
            GlassIconButton(Glyph.edit,
                onPressed: () => _openEdit()),
            if (user!.isAdmin) GlassIconButton(Glyph.delete, onPressed: _deleteCompany),
          ],
        ],
      ),
      body: _loading
          ? const LoadingView()
          : c == null
              ? const Center(child: Text('Компания не найдена'))
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    RealGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          if ((c.industry ?? '').isNotEmpty)
                            _row(Glyph.briefcase, c.industry!),
                          if ((c.address ?? '').isNotEmpty) _row(Glyph.pin, c.address!),
                          if ((c.email ?? '').isNotEmpty) _row(Glyph.mail, c.email!),
                          if ((c.phone ?? '').isNotEmpty) _row(Glyph.phone, c.phone!),
                          _row(Glyph.list, '$_vacancyCount вакансий'),
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text('Контактные лица (${_contacts.length})',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                                if (canManage)
                                  GlassIconButton(Glyph.add,
                                      size: 20, onPressed: () => _openContactForm()),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_contacts.isEmpty)
                              Text('Контакты не добавлены',
                                  style:
                                      TextStyle(color: Colors.white.withOpacity(0.5)))
                            else
                              for (final ct in _contacts)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    children: [
                                      const GlassIcon(Glyph.person, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(ct.fullName,
                                                style: const
                                                    TextStyle(fontWeight: FontWeight.w600)),
                                            if ((ct.position ?? '').isNotEmpty ||
                                                (ct.phone ?? '').isNotEmpty ||
                                                (ct.email ?? '').isNotEmpty)
                                              Text(
                                                [
                                                  if ((ct.position ?? '').isNotEmpty)
                                                    ct.position!,
                                                  if ((ct.phone ?? '').isNotEmpty) ct.phone!,
                                                  if ((ct.email ?? '').isNotEmpty) ct.email!,
                                                ].join(' · '),
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        Colors.white.withOpacity(0.6)),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (canManage)
                                        GlassIconButton(Glyph.edit,
                                            size: 16,
                                            onPressed: () =>
                                                _openContactForm(existing: ct)),
                                      if (user!.isAdmin)
                                        GlassIconButton(Glyph.delete,
                                            size: 16, onPressed: () => _deleteContact(ct)),
                                    ],
                                  ),
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

  Future<void> _openEdit() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _CompanyFormDialog(existing: _company),
    );
    if (changed == true) _load();
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
}

/// Create/edit company dialog (manager/admin).
class _CompanyFormDialog extends StatefulWidget {
  final CompanyItem? existing;
  const _CompanyFormDialog({this.existing});

  @override
  State<_CompanyFormDialog> createState() => _CompanyFormDialogState();
}

class _CompanyFormDialogState extends State<_CompanyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _address = TextEditingController(text: widget.existing?.address ?? '');
  late final _industry = TextEditingController(text: widget.existing?.industry ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _industry.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final body = <String, dynamic>{
      'full_name': _name.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'industry': _industry.text.trim().isEmpty ? null : _industry.text.trim(),
    };
    setState(() => _saving = true);
    final ok = await runGuarded(context, () async {
      final api = AppScope.read(context).api;
      if (widget.existing != null) {
        await api.put('/companies/${widget.existing!.id}', body);
      } else {
        await api.post('/companies', body);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Новая компания' : 'Правка компании'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: _name,
                label: 'Название *',
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Минимум 2 символа' : null,
              ),
              AppTextField(controller: _industry, label: 'Отрасль'),
              AppTextField(controller: _address, label: 'Адрес'),
              AppTextField(
                  controller: _email,
                  label: 'E-mail',
                  keyboardType: TextInputType.emailAddress),
              AppTextField(controller: _phone, label: 'Телефон'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '…' : 'Сохранить')),
      ],
    );
  }
}

/// Create/edit contact dialog (manager/admin).
class _ContactFormDialog extends StatefulWidget {
  final int companyId;
  final ContactItem? existing;
  const _ContactFormDialog({required this.companyId, this.existing});

  @override
  State<_ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<_ContactFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _fullName =
      TextEditingController(text: widget.existing?.fullName ?? '');
  late final _position = TextEditingController(text: widget.existing?.position ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _fullName.dispose();
    _position.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final body = <String, dynamic>{
      'full_name': _fullName.text.trim(),
      'position': _position.text.trim().isEmpty ? null : _position.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'company_id': widget.companyId,
    };
    setState(() => _saving = true);
    final ok = await runGuarded(context, () async {
      final api = AppScope.read(context).api;
      if (widget.existing != null) {
        await api.put('/contacts/${widget.existing!.id}', body);
      } else {
        await api.post('/contacts', body);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Новый контакт' : 'Правка контакта'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: _fullName,
                label: 'ФИО *',
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Минимум 2 символа' : null,
              ),
              AppTextField(controller: _position, label: 'Должность'),
              AppTextField(controller: _phone, label: 'Телефон'),
              AppTextField(
                  controller: _email,
                  label: 'E-mail',
                  keyboardType: TextInputType.emailAddress),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '…' : 'Сохранить')),
      ],
    );
  }
}
