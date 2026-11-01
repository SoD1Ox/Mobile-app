/// Companies list — partner employers.  CRUD + search, pagination via PagerBar.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
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
  int _pages = 1;
  int _page = 1;
  String _search = '';
  bool _loading = true;

  static const _pageSize = 20;

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
    final api = AppScope.read(context).api;
    try {
      final raw = await api.get('/companies', {
        'page': _page,
        'page_size': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
      });
      final p = DataPage.fromJson(raw as Map<String, dynamic>, CompanyItem.fromJson);
      if (!mounted) return;
      setState(() {
        _items = p.items;
        _total = p.total;
        _pages = p.pages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  void _applySearch() {
    setState(() {
      _search = _searchController.text.trim();
      _page = 1;
    });
    _load();
  }

  Future<void> _openForm({CompanyItem? existing}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _CompanyFormScreen(existing: existing)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(CompanyItem c) async {
    final ok = await confirmDialog(context, 'Удалить компанию?',
        '«${c.name}» будет удалена вместе с её вакансиями.');
    if (!ok) return;
    final api = AppScope.read(context).api;
    final done = await runGuarded(context, () => api.delete('/companies/${c.id}'));
    if (done) _load();
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
                hintText: 'Поиск по названию / отрасли…',
                prefixIcon: const GlassIcon(Glyph.search, size: 20),
                suffixIcon: _search.isEmpty
                    ? null
                    : GlassIconButton(Glyph.close, size: 18, onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                        _load();
                      }),
              ),
              onSubmitted: (_) => _applySearch(),
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
          : Column(
              children: [
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('Компании не найдены'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (context, i) {
                              final c = _items[i];
                              return GlassListCard(
                                onTap: () => _openForm(existing: c),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          color: const Color(0x335B8CFF),
                                        ),
                                        child: const Center(
                                            child: GlassIcon(Glyph.building,
                                                size: 22)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(c.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 4),
                                            Text(
                                              [
                                                c.industry ?? 'Отрасль не указана',
                                                if (c.address != null) c.address!,
                                              ].join(' · '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: Colors.white
                                                      .withOpacity(0.6)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (user?.canManage ?? false)
                                        GlassIconButton(Glyph.delete,
                                            size: 18,
                                            tooltip: 'Удалить',
                                            onPressed: () => _delete(c)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                PagerBar(
                  page: _page,
                  pages: _pages,
                  onChanged: (p) {
                    setState(() => _page = p);
                    _load();
                  },
                ),
                Text('Всего компаний: $_total',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 96),
              ],
            ),
    );
  }
}

/// Inline company create/edit form (bottom-sheet style full screen route).
class _CompanyFormScreen extends StatefulWidget {
  final CompanyItem? existing;
  const _CompanyFormScreen({this.existing});

  @override
  State<_CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<_CompanyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _industry = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _email.text = e.email ?? '';
      _phone.text = e.phone ?? '';
      _address.text = e.address ?? '';
      _industry.text = e.industry ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address, _industry]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'industry': _industry.text.trim().isEmpty ? null : _industry.text.trim(),
    };
    final api = AppScope.read(context).api;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await api.put('/companies/${widget.existing!.id}', body);
      } else {
        await api.post('/companies', body);
      }
      if (!mounted) return;
      showInfo(context, _isEdit ? 'Компания обновлена' : 'Компания добавлена');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Редактирование компании' : 'Новая компания')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _name,
              label: 'Название *',
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Минимум 2 символа' : null,
            ),
            AppTextField(controller: _industry, label: 'Отрасль'),
            AppTextField(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            AppTextField(
              controller: _phone,
              label: 'Телефон',
              keyboardType: TextInputType.phone,
            ),
            AppTextField(controller: _address, label: 'Адрес'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const GlassIcon(Glyph.save, size: 18),
              label: Text(_isEdit ? 'Сохранить изменения' : 'Добавить компанию'),
            ),
          ],
        ),
      ),
    );
  }
}
