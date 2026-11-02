/// Candidate list: search + city/specialization filters + infinite scroll.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/glass.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';
import 'candidate_detail_screen.dart';
import 'candidate_form_screen.dart';

class CandidatesScreen extends StatefulWidget {
  const CandidatesScreen({super.key});

  @override
  State<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends State<CandidatesScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  List<CandidateItem> _items = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;

  String _search = '';
  String? _city;
  String? _specialization;

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
    _searchController.dispose();
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
      final api = AppScope.read(context).api;
      final next = reset ? 1 : _page + 1;
      final raw = await api.get('/candidates', {
        'page': next,
        'page_size': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
        if (_city != null) 'city': _city,
        if (_specialization != null) 'specialization': _specialization,
      });
      final page = DataPage.fromJson(raw, CandidateItem.fromJson);
      if (!mounted) return;
      setState(() {
        _items = reset ? page.items : [..._items, ...page.items];
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

  Future<void> _openForm({CandidateItem? existing}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => CandidateFormScreen(existing: existing)),
    );
    if (changed == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.read(context).user;
    final hasFilters =
        _search.isNotEmpty || _city != null || _specialization != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кандидаты'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(118),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: appTextColor(context)),
                  decoration: InputDecoration(
                    hintText: 'Поиск по имени / специализации…',
                    prefixIcon: const GlassIcon(Glyph.search, size: 20),
                    suffixIcon: _search.isEmpty
                        ? null
                        : GlassIconButton(Glyph.close, size: 18, onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                            _load(reset: true);
                          }),
                  ),
                  onSubmitted: (v) {
                    setState(() => _search = v.trim());
                    _load(reset: true);
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(_city ?? 'Город: любой'),
                      selected: _city != null,
                      onSelected: (_) => _pickValue(
                          'Город',
                          _items
                              .map((e) => e.city)
                              .whereType<String>()
                              .toSet()
                              .toList()
                            ..sort(),
                          (v) => _city = v),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(_specialization ?? 'Специализация: любая'),
                      selected: _specialization != null,
                      onSelected: (_) => _pickValue(
                          'Специализация',
                          _items
                              .map((e) => e.specialization)
                              .whereType<String>()
                              .toSet()
                              .toList()
                            ..sort(),
                          (v) => _specialization = v),
                    ),
                    if (hasFilters) ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const GlassIcon(Glyph.close, size: 15),
                        label: const Text('Сбросить'),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _search = '';
                            _city = null;
                            _specialization = null;
                          });
                          _load(reset: true);
                        },
                      ),
                    ],
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('Всего: $_total'),
                      avatar: const GlassIcon(Glyph.list, size: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: (user?.canManage ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const GlassIcon(Glyph.add, size: 20),
              label: const Text('Новый кандидат'),
            )
          : null,
      body: _items.isEmpty && !_loading
          ? const Center(child: Text('Кандидаты не найдены'))
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
                  final c = _items[i];
                  return GlassListCard(
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CandidateDetailScreen(candidateId: c.id)),
                      );
                      if (changed == true) _load(reset: true);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: kAccentColor.withOpacity(0.25),
                            child: Text(
                                c.fullName.characters.first.toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    c.specialization ?? 'Без специализации',
                                    c.expLabel,
                                    if (c.city != null) c.city!,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color:
                                          appTextColor(context, opacity: 0.72)),
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

  Future<void> _pickValue(
      String title, List<String> values, ValueSetter<String?> apply) async {
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          for (final value in values)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, value), child: Text(value)),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Все')),
        ],
      ),
    );
    if (v != null && mounted) {
      setState(() => apply(v.isEmpty ? null : v));
      _load(reset: true);
    }
  }
}
