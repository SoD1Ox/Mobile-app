/// Candidate list — the second main agency entity.  Server-side pagination
/// with infinite scroll, live search and city/specialization filters.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../utils/local_store.dart';
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

  final _recent = RecentSearches();
  List<String> _recentSearches = [];

  static const _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
    _recent.load('candidates').then((l) {
      if (mounted) setState(() => _recentSearches = l);
    });
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

  void _applySearch(String v) {
    _recent.push('candidates', v);
    setState(() {
      _search = v.trim();
      final q = v.trim();
      _recentSearches = q.isEmpty
          ? _recentSearches
          : [
              q,
              ..._recentSearches.where((e) => e.toLowerCase() != q.toLowerCase())
            ].take(6).toList();
    });
    _load(reset: true);
  }

  Future<void> _openForm({CandidateItem? existing}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CandidateFormScreen(existing: existing)),
    );
    if (changed == true) _load(reset: true);
  }

  Future<void> _pickFromDialog(String title, List<String> options,
      {bool allowAll = true, String? current}) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          for (final o in options)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, o), child: Text(o)),
          if (allowAll)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('Все')),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (title == 'Город') {
        _city = picked.isEmpty ? null : picked;
      } else {
        _specialization = picked.isEmpty ? null : picked;
      }
    });
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.read(context).user;
    final hasFilters = _search.isNotEmpty || _city != null || _specialization != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кандидаты'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(_recentSearches.isEmpty ? 118 : 154),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Поиск по ФИО / специализации…',
                    prefixIcon: const GlassIcon(Glyph.search, size: 20),
                    suffixIcon: _search.isEmpty
                        ? null
                        : GlassIconButton(Glyph.close,
                            size: 18,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                              _load(reset: true);
                            }),
                  ),
                  onSubmitted: _applySearch,
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      avatar: const GlassIcon(Glyph.pin, size: 15),
                      label: Text(_city ?? 'Все города'),
                      selected: _city != null,
                      onSelected: (_) => _pickFromDialog(
                          'Город',
                          (_items
                                  .map((e) => e.city)
                                  .whereType<String>()
                                  .toSet()
                                  .toList()
                                ..sort()),
                          current: _city),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const GlassIcon(Glyph.person, size: 15),
                      label: Text(_specialization ?? 'Специализация: любая'),
                      selected: _specialization != null,
                      onSelected: (_) => _pickFromDialog(
                          'Специализация',
                          (_items
                                  .map((e) => e.specialization)
                                  .whereType<String>()
                                  .toSet()
                                  .toList()
                                ..sort()),
                          current: _specialization),
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
              if (_recentSearches.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Row(
                    children: [
                      const Text('Недавние: ',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      for (final q in _recentSearches)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(q, style: const TextStyle(fontSize: 12)),
                            onPressed: () {
                              _searchController.text = q;
                              _applySearch(q);
                            },
                          ),
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
        icon: const GlassIcon(Glyph.add, size: 20),
        label: const Text('Новый кандидат'),
      ),
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
                            radius: 21,
                            backgroundColor: const Color(0x335B8CFF),
                            child: Text(
                              c.fullName.split(' ').map((p) => p.isEmpty ? '' : p[0]).take(2).join(),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
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
                                        fontSize: 15.5, fontWeight: FontWeight.w700)),
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
                                      color: Colors.white.withOpacity(0.6))),
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
