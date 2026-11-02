/// Create/edit form for vacancies.  `existing == null` means CREATE.
/// Company and skills are picked from data loaded from the backend; a new
/// skill can be created on the fly (POST /skills) — nice for recruiters.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';

class VacancyFormScreen extends StatefulWidget {
  final VacancyItem? existing; // null => create
  const VacancyFormScreen({super.key, this.existing});

  @override
  State<VacancyFormScreen> createState() => _VacancyFormScreenState();
}

class _VacancyFormScreenState extends State<VacancyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _salaryFrom = TextEditingController();
  final _salaryTo = TextEditingController();
  final _city = TextEditingController();
  final _newSkill = TextEditingController();

  bool _remote = false;
  int? _companyId;
  final Set<int> _skillIds = {};

  List<CompanyItem> _companies = [];
  List<SkillItem> _skills = [];
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadRefs();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _description.text = e.description ?? '';
      _salaryFrom.text = e.salaryFrom?.toStringAsFixed(0) ?? '';
      _salaryTo.text = e.salaryTo?.toStringAsFixed(0) ?? '';
      _city.text = e.city ?? '';
      _remote = e.remote;
      _companyId = e.companyId;
      _skillIds.addAll(e.skills.map((s) => s.id));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _salaryFrom,
      _salaryTo,
      _city,
      _newSkill
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRefs() async {
    final api = AppScope.read(context).api;
    try {
      final results = await Future.wait([
        api.get('/companies', {'page_size': 200}),
        api.get('/skills'),
      ]);
      if (!mounted) return;
      setState(() {
        _companies = DataPage.fromJson(
                results[0] is Map<String, dynamic>
                    ? results[0] as Map<String, dynamic>
                    : <String, dynamic>{},
                CompanyItem.fromJson)
            .items;
        _skills = (results[1] is List ? results[1] as List : const [])
            .whereType<Map>()
            .map((e) => SkillItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _addSkill() async {
    final name = _newSkill.text.trim();
    if (name.isEmpty) return;
    final api = AppScope.read(context).api;
    try {
      final created =
          await api.post('/skills', {'name': name}) as Map<String, dynamic>;
      final skill = SkillItem.fromJson(created);
      if (!mounted) return;
      setState(() {
        _skills = [..._skills, skill]..sort((a, b) => a.name.compareTo(b.name));
        _skillIds.add(skill.id);
        _newSkill.clear();
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_companyId == null) {
      showError(context, 'Выберите компанию-работодателя');
      return;
    }
    double? num(TextEditingController c) => double.tryParse(c.text.trim());
    final sf = num(_salaryFrom);
    final st = num(_salaryTo);
    if (sf != null && st != null && st < sf) {
      showError(context, 'Зарплата «до» меньше зарплаты «от»');
      return;
    }
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'description':
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      'salary_from': sf,
      'salary_to': st,
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'remote': _remote,
      'company_id': _companyId,
      'skill_ids': _skillIds.toList(),
    };
    final api = AppScope.read(context).api;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await api.put('/vacancies/${widget.existing!.id}', body);
      } else {
        await api.post('/vacancies', body);
      }
      if (!mounted) return;
      AppScope.read(context).notifications.add(
            _isEdit ? 'Вакансия обновлена' : 'Создана новая вакансия',
            _title.text.trim(),
          );
      showInfo(context, _isEdit ? 'Вакансия обновлена' : 'Вакансия создана');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateNum(String? v, String label) {
    if (v == null || v.trim().isEmpty) return null;
    if (double.tryParse(v.trim()) == null)
      return '$label — число, например 120000';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'Редактирование вакансии' : 'Новая вакансия')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _title,
              label: 'Название должности *',
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Минимум 2 символа'
                  : null,
            ),
            AppDropdown<int>(
              label: 'Компания-работодатель *',
              value: _companyId,
              validator: (v) => v == null ? 'Выберите компанию' : null,
              onChanged: (v) => setState(() => _companyId = v),
              items: [
                for (final c in _companies)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
            ),
            AppTextField(
              controller: _description,
              label: 'Описание',
              maxLines: 5,
            ),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _salaryFrom,
                    label: 'Зарплата от, ₽',
                    keyboardType: TextInputType.number,
                    validator: (v) => _validateNum(v, '«от»'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    controller: _salaryTo,
                    label: 'Зарплата до, ₽',
                    keyboardType: TextInputType.number,
                    validator: (v) => _validateNum(v, '«до»'),
                  ),
                ),
              ],
            ),
            AppTextField(controller: _city, label: 'Город'),
            SwitchListTile(
              value: _remote,
              onChanged: (v) => setState(() => _remote = v),
              contentPadding: EdgeInsets.zero,
              title: const Text('Удалённая работа'),
              secondary: const GlassIcon(Glyph.briefcase, size: 20),
              activeColor: Color(0xFF5B8CFF),
            ),
            const SizedBox(height: 8),
            const Text('Навыки', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _skills)
                  FilterChip(
                    label: Text(s.name),
                    selected: _skillIds.contains(s.id),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _skillIds.add(s.id);
                      } else {
                        _skillIds.remove(s.id);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _newSkill,
                    label: 'Добавить новый навык',
                  ),
                ),
                const SizedBox(width: 8),
                GlassIconButton(Glyph.add, onPressed: _addSkill),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const GlassIcon(Glyph.save, size: 18),
              label: Text(_isEdit ? 'Сохранить изменения' : 'Создать вакансию'),
            ),
          ],
        ),
      ),
    );
  }
}
