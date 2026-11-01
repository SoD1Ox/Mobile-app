/// Create/edit vacancy form (manager/admin).  Demonstrates the full CREATE
/// flow of the API: company picker, skill multi-select, salary range.
library;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../theme/glass_stack.dart';
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

  List<CompanyItem> _companies = [];
  List<SkillItem> _allSkills = [];
  int? _companyId;
  final Set<int> _skillIds = {};
  bool _remote = false;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _description.text = e.description ?? '';
      _salaryFrom.text = e.salaryFrom?.toStringAsFixed(0) ?? '';
      _salaryTo.text = e.salaryTo?.toStringAsFixed(0) ?? '';
      _city.text = e.city ?? '';
      _companyId = e.companyId;
      _remote = e.remote;
      _skillIds.addAll(e.skills.map((s) => s.id));
    }
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    try {
      final api = AppScope.read(context).api;
      final results = await Future.wait([
        api.get('/companies', {'page_size': 200}),
        api.get('/skills'),
      ]);
      if (!mounted) return;
      setState(() {
        _companies =
            DataPage.fromJson(results[0], CompanyItem.fromJson).items;
        _allSkills = (results[1] as List)
            .map((e) => SkillItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, err);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_companyId == null) {
      showError(context, ApiException('Выберите компанию'));
      return;
    }
    double? num(String s) => s.trim().isEmpty ? null : double.tryParse(s.trim());
    final sf = num(_salaryFrom.text);
    final st = num(_salaryTo.text);
    if (sf != null && st != null && st < sf) {
      showError(context, ApiException('Зарплата «до» меньше зарплаты «от»'));
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
    setState(() => _saving = true);
    final ok = await runGuarded(context, () async {
      if (_isEdit) {
        await AppScope.read(context)
            .api
            .put('/vacancies/${widget.existing!.id}', body);
      } else {
        await AppScope.read(context).api.post('/vacancies', body);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      showInfo(context, _isEdit ? 'Вакансия обновлена' : 'Вакансия создана');
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _salaryFrom.dispose();
    _salaryTo.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Правка вакансии' : 'Новая вакансия')),
      body: _loading
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  RealGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _title,
                          label: 'Должность *',
                          validator: (v) =>
                              (v == null || v.trim().length < 2) ? 'Минимум 2 символа' : null,
                        ),
                        AppDropdown<int>(
                          label: 'Компания *',
                          value: _companyId,
                          validator: (v) => v == null ? 'Выберите компанию' : null,
                          onChanged: (v) => setState(() => _companyId = v),
                          items: [
                            for (final c in _companies)
                              DropdownMenuItem(value: c.id, child: Text(c.name)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _salaryFrom,
                                label: 'Зарплата от, ₽',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppTextField(
                                controller: _salaryTo,
                                label: 'Зарплата до, ₽',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        AppTextField(controller: _city, label: 'Город'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _remote,
                          onChanged: (v) => setState(() => _remote = v),
                          title: const Text('Удалённая работа'),
                          secondary: const GlassIcon(Glyph.pin, size: 20),
                        ),
                        AppTextField(
                          controller: _description,
                          label: 'Описание',
                          maxLines: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_allSkills.isNotEmpty)
                    GlassListCard(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Требуемые навыки',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final s in _allSkills)
                                  FilterChip(
                                    label: Text(s.name),
                                    selected: _skillIds.contains(s.id),
                                    onSelected: (on) => setState(() =>
                                        on ? _skillIds.add(s.id) : _skillIds.remove(s.id)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const GlassIcon(Glyph.save, size: 18),
                    label: Text(_isEdit ? 'Сохранить' : 'Создать вакансию'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
