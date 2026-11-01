/// Vacancy list: the main agency entity.  Demonstrates the large-data
/// mechanism on the client side — server-side pagination with infinite
/// scroll ("load more"), live search and city/remote/salary filters.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme/glass.dart';
import '../utils/local_store.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';
import 'vacancy_detail_screen.dart';
import 'vacancy_form_screen.dart';

class VacanciesScreen extends StatefulWidget {
  const VacanciesScreen({super.key});

  @override
  State<VacanciesScreen> createState() => _VacanciesScreenState();
}

class _VacanciesScreenState extends State<VacanciesScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  List<VacancyItem> _items = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;

  /// Server page currently being fetched (1-based).  Used to drop responses
  /// that arrive after a filter reset (race protection for infinite scroll).
  int _fetchSeq = 0;

  String _search = '';
  String? _city;
  bool? _remote;
  double? _salaryMin;

  // -------- local features: favourites + recent searches -----------------
  final _favs = FavoritesStore();
  final _recent = RecentSearches();
  Set<int> _favIds = {};
  bool _onlyFavs = false;
  List<String> _recentSearches = [];

  static const _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
    _favs.load().then((s) {
      if (mounted) setState(() => _favIds = s);
    });
    _recent.load('vacancies').then((l) {
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
      final raw = await api.get('/vacancies', {
        'page': next,
        'page_size': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
        if (_city != null) 'city': _city,
        if (_remote != null) 'remote': _remote,
        if (_salaryMin != null) 'salary_min': _salaryMin,
      });
      final page = DataPage.fromJson(raw, VacancyItem.fromJson);
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
    _recent.push('vacancies', v);
    setState(() {
      _search = v.trim();
      _recentSearches = List.of(_recentCacheWith(v));
    });
    _load(reset: true);
  }

  Iterable<String> _recentCacheWith(String v) {
    final q = v.trim();
    if (q.isEmpty) return _recentSearches;
    return [q, ..._recentSearches.where((e) => e.toLowerCase() != q.toLowerCase())].take(6);
  }

  Future<void> _toggleFav(int id) async {
    await _favs.toggle(id);
    if (!mounted) return;
    setState(() {
      if (_favIds.contains(id)) {
        _favIds.remove(id);
      } else {
        _favIds.add(id);
      }
    });
  }

  Future<void> _openForm({VacancyItem? vacancy}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => VacancyFormScreen(existing: vacancy)),
    );
    if (changed == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.read(context).user;
    final hasFilters =
        _search.isNotEmpty || _city != null || _remote != null || _salaryMin != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вакансии'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(118),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию / описанию…',
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
                      avatar: GlassIcon(
                          _onlyFavs ? Glyph.star : Glyph.close, size: 15),
                      label: Text(_onlyFavs ? '★ Избранное' : 'Все вакансии'),
                      selected: _onlyFavs,
                      onSelected: (_) {
                        setState(() => _onlyFavs = !_onlyFavs);
                        _load(reset: true);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(_city == null ? 'Все города' : _city!),
                      selected: _city != null,
                      onSelected: (_) => _pickCity(),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const GlassIcon(Glyph.pin, size: 15),
                      label: Text(_remote == null
                          ? 'Формат: любой'
                          : (_remote! ? 'Только удалёнка' : 'В офисе')),
                      selected: _remote != null,
                      onSelected: (_) => _cycleRemote(),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(_salaryMin == null
                          ? 'Зарплата: любая'
                          : 'от ${_salaryMin!.toStringAsFixed(0)} ₽'),
                      selected: _salaryMin != null,
                      onSelected: (_) => _pickSalary(),
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
                            _remote = null;
                            _salaryMin = null;
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
              label: const Text('Новая вакансия'),
            )
          : null,
      body: _items.isEmpty && !_loading
          ? const Center(child: Text('Вакансии не найдены'))
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
                  final v = _items[i];
                  return GlassListCard(
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                VacancyDetailScreen(vacancyId: v.id)),
                      );
                      if (changed == true) _load(reset: true);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(v.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700)),
                              ),
                              if (v.remote)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: StatusChip(
                                      label: 'Удалённо', color: Color(0xFF26C6DA)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              GlassIcon(Glyph.money, size: 15),
                              Text(v.salaryLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8CE99A))),
                              if (v.city != null) ...[
                                Text(' · ',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.4))),
                                GlassIcon(Glyph.pin, size: 15),
                                Text(v.city!,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.75))),
                              ],
                            ],
                          ),
                          if (v.skills.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(v.skills.map((e) => e.name).take(6).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.55))),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _pickCity() async {
    // Collect distinct cities from the loaded page + a free-text entry.
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Город'),
        children: [
          for (final city in (_items
              .map((e) => e.city)
              .whereType<String>()
              .toSet()
              .toList()
            ..sort()))
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, city), child: Text(city)),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ''), child: const Text('Все')),
        ],
      ),
    );
    if (v != null) {
      if (!mounted) return;
      setState(() => _city = v.isEmpty ? null : v);
      _load(reset: true);
    }
  }

  void _cycleRemote() {
    setState(() {
      _remote = _remote == null ? true : (_remote == true ? false : null);
    });
    _load(reset: true);
  }

  Future<void> _pickSalary() async {
    final presets = <String, double>{
      'от 80 000 ₽': 80000,
      'от 150 000 ₽': 150000,
      'от 250 000 ₽': 250000,
      'от 350 000 ₽': 350000,
      'Любая': 0,
    };
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Минимальная зарплата'),
        children: [
          for (final e in presets.entries)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, e.key), child: Text(e.key)),
        ],
      ),
    );
    if (label != null) {
      if (!mounted) return;
      final v = presets[label]!;
      setState(() => _salaryMin = v == 0 ? null : v);
      _load(reset: true);
    }
  }
}
