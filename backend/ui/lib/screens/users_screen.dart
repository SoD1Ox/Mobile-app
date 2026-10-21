/// User management screen — the interface for the 4th entity (users).
/// Available to ADMIN role only; list/create/edit/delete + role & is_active.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/common.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  static const _roleLabels = {
    'admin': 'Администратор',
    'manager': 'Менеджер',
    'worker': 'Сотрудник',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await AppScope.of(context).api.get('/users');
      setState(() {
        _users = (raw as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _UserFormScreen(existing: existing)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> u) async {
    final yes = await confirmDialog(
        context,
        'Удалить пользователя?',
        '«${u['username']}» (${_roleLabels[u['role']] ?? u['role']}) будет удалён навсегда.');
    if (!yes) return;
    final ok = await runGuarded(
        context, () => AppScope.of(context).api.delete('/users/${u['id']}'));
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = AppScope.of(context).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Пользователи')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.person_add),
          label: const Text('Пользователь')),
      body: _loading
          ? const LoadingView()
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (_, i) {
                final u = _users[i];
                final role = '${u['role']}';
                final isMe = me?.id == u['id'];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                        child: Text((u['full_name'] as String? ?? '?')
                            .characters
                            .first
                            .toUpperCase())),
                    title: Text(u['full_name'] ?? u['username'],
                        // ignore: dead_null_aware_expression
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '@${u['username']} · ${u['email']}\n${_roleLabels[role] ?? role}'
                        '${u['is_active'] == false ? ' · неактивен' : ''}'),
                    isThreeLine: true,
                    trailing: isMe
                        ? const Tooltip(
                            message: 'Это вы', child: Icon(Icons.person))
                        : Wrap(spacing: 4, children: [
                            IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openForm(existing: u)),
                            IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => _delete(u)),
                          ]),
                  ),
                );
              },
            ),
    );
  }
}

class _UserFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const _UserFormScreen({this.existing});

  @override
  State<_UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<_UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _username = TextEditingController(
      text: widget.existing?['username'] ?? '');
  late final _email =
      TextEditingController(text: widget.existing?['email'] ?? '');
  late final _fullName = TextEditingController(
      text: widget.existing?['full_name'] ?? '');
  late final _password = TextEditingController();
  late String _role = widget.existing?['role'] ?? 'worker';
  late bool _isActive = widget.existing?['is_active'] ?? true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_username, _email, _fullName, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = AppScope.of(context).api;
    final body = <String, dynamic>{
      'username': _username.text.trim(),
      'email': _email.text.trim(),
      'full_name': _fullName.text.trim(),
      'role': _role,
      'is_active': _isActive,
      if (_password.text.isNotEmpty) 'password': _password.text,
    };
    final ok = await runGuarded(context, () async {
      if (_isEdit) {
        await api.put('/users/${widget.existing!['id']}', body);
      } else {
        await api.post('/users', body);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      showInfo(context, _isEdit ? 'Пользователь обновлён' : 'Пользователь создан');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'Редактирование пользователя' : 'Новый пользователь')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
                controller: _username,
                label: 'Логин *',
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Минимум 3 символа'
                    : null),
            AppTextField(
                controller: _email,
                label: 'Email *',
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Некорректный email' : null),
            AppTextField(
                controller: _fullName,
                label: 'ФИО *',
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Минимум 2 символа'
                    : null),
            AppTextField(
              controller: _password,
              label: _isEdit ? 'Новый пароль (не обязательно)' : 'Пароль *',
              obscureText: true,
              validator: (v) {
                if (!_isEdit && (v == null || v.length < 6)) {
                  return 'Минимум 6 символов';
                }
                if (v != null && v.isNotEmpty && v.length < 6) {
                  return 'Минимум 6 символов';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(
                  labelText: 'Роль', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Администратор')),
                DropdownMenuItem(value: 'manager', child: Text('Менеджер')),
                DropdownMenuItem(value: 'worker', child: Text('Сотрудник')),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
            SwitchListTile(
              title: const Text('Активен'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isEdit ? 'Сохранить' : 'Создать')),
          ],
        ),
      ),
    );
  }
}
