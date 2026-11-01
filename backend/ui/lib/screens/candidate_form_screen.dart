/// Candidate create/edit form (manager/admin).
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/glass_stack.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';

class CandidateFormScreen extends StatefulWidget {
  final CandidateItem? existing; // null => create
  const CandidateFormScreen({super.key, this.existing});

  @override
  State<CandidateFormScreen> createState() => _CandidateFormScreenState();
}

class _CandidateFormScreenState extends State<CandidateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _specialization = TextEditingController();
  final _experience = TextEditingController(text: '0');
  final _resumeUrl = TextEditingController();

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _fullName.text = e.fullName;
      _email.text = e.email ?? '';
      _phone.text = e.phone ?? '';
      _city.text = e.city ?? '';
      _specialization.text = e.specialization ?? '';
      _experience.text = '${e.experienceYears}';
      _resumeUrl.text = e.resumeUrl ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _email,
      _phone,
      _city,
      _specialization,
      _experience,
      _resumeUrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final body = <String, dynamic>{
      'full_name': _fullName.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'specialization':
          _specialization.text.trim().isEmpty ? null : _specialization.text.trim(),
      'experience_years': int.tryParse(_experience.text.trim()) ?? 0,
      'resume_url': _resumeUrl.text.trim().isEmpty ? null : _resumeUrl.text.trim(),
    };
    setState(() => _saving = true);
    final ok = await runGuarded(context, () async {
      final api = AppScope.read(context).api;
      if (_isEdit) {
        await api.put('/candidates/${widget.existing!.id}', body);
      } else {
        await api.post('/candidates', body);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      showInfo(context, _isEdit ? 'Кандидат обновлён' : 'Кандидат добавлен');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Правка кандидата' : 'Новый кандидат')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RealGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: _fullName,
                    label: 'ФИО *',
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? 'Минимум 2 символа' : null,
                  ),
                  AppTextField(
                    controller: _email,
                    label: 'E-mail',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return null;
                      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
                          ? null
                          : 'Некорректный e-mail';
                    },
                  ),
                  AppTextField(
                      controller: _phone, label: 'Телефон', keyboardType: TextInputType.phone),
                  AppTextField(controller: _city, label: 'Город'),
                  AppTextField(controller: _specialization, label: 'Специализация'),
                  AppTextField(
                    controller: _experience,
                    label: 'Опыт работы, лет',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return null;
                      final n = int.tryParse(v!.trim());
                      return (n == null || n < 0 || n > 70) ? 'От 0 до 70' : null;
                    },
                  ),
                  AppTextField(controller: _resumeUrl, label: 'Ссылка на резюме'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const GlassIcon(Glyph.save, size: 18),
              label: Text(_isEdit ? 'Сохранить' : 'Добавить кандидата'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
