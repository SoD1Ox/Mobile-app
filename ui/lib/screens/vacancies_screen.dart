/// Vacancy list: the main agency entity.  Demonstrates the large-data
/// mechanism on the client side — server-side pagination with infinite
/// scroll ("load more"), live search and city/remote/salary filters.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/glass_icons.dart';
import 'vacancy_detail_screen.dart';
import 'vacancy_form_screen.dart';

class VacanciesScreen extends StatefulWidget {
  final bool initialFavorites;
  const VacanciesScreen({super.key, this.initialFavorites = false});

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
  bool _favoritesReady = false;
  bool _showFavorites = false;
  final Set<int> _favoriteIds = {};

  String _search = '';
  String? _city;
  bool? _remote;
  double? _salaryMin;
  String _sort = 'newest';

  static const _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _showFavorites = widget.initialFavorites;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFavorites());
  }

  Future<void> _loadFavorites() async {
    final user = AppScope.read(context).user;
    final prefs = await SharedPreferences.getInstance();
    final ids = user == null
        ? <int>{}
        : (prefs.getStringList('favorite_vacancies_${user.id}') ?? const [])
            .map(int.tryParse)
            .whereType<int>()
            .toSet();
    if (!mounted) return;
    setState(() {
      _favoriteIds
        ..clear()
        ..addAll(ids);
      _favoritesReady = true;
    });
    await _load(reset: true);
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
    if (_loading || !_favoritesReady) return;
    setState(() => _loading = true);
    try {
      final api = AppScope.read(context).api;
      if (_showFavorites && _favoriteIds.isEmpty) {
        if (mounted) {
          setState(() {
            _items = [];
            _total = 0;
            _page = 0;
            _hasMore = false;
          });
        }
        return;
      }
      final next = reset ? 1 : _page + 1;
      final raw = await api.get('/vacancies', {
        'page': next,
        'page_size': _pageSize,
        'sort': _sort,
        if (_showFavorites) 'ids': _favoriteIds.join(','),
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

  Future<void> _toggleFavorite(VacancyItem vacancy) async {
    final user = AppScope.read(context).user;
    if (user == null) return;
    final wasSaved = _favoriteIds.contains(vacancy.id);
    setState(() {
      if (wasSaved) {
        _favoriteIds.remove(vacancy.id);
      } else {
        _favoriteIds.add(vacancy.id);
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'favorite_vacancies_${user.id}',
        (_favoriteIds.toList()..sort()).map((id) => '$id').toList(),
      );
      AppScope.read(context).notifications.add(
            wasSaved ? 'Убрано из избранного' : 'Вакансия сохранена',
            '«${vacancy.title}» ${wasSaved ? 'удалена из списка сохранённых' : 'добавлена в избранное'}.',
          );
      if (_showFavorites) await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _favoriteIds.add(vacancy.id);
        } else {
          _favoriteIds.remove(vacancy.id);
        }
      });
      showError(context, e);
    }
  }

  Future<void> _openForm({VacancyItem? vacancy}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VacancyFormScreen(existing: vacancy)),
    );
    if (changed == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.read(context).user;
    final hasFilters = _search.isNotEmpty ||
        _city != null ||
        _remote != null ||
        _salaryMin != null ||
        _showFavorites;
    return Scaffold(
      appBar: AppBar(
        title: Text(_showFavorites ? 'Избранное' : 'Вакансии'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Сортировка',
            initialValue: _sort,
            onSelected: (value) {
              setState(() => _sort = value);
              _load(reset: true);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'newest', child: Text('Сначала новые')),
              PopupMenuItem(
                  value: 'salary_desc', child: Text('Сначала выше зарплата')),
              PopupMenuItem(
                  value: 'salary_asc', child: Text('Сначала ниже зарплата')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  GlassIcon(Glyph.list, size: 18),
                  SizedBox(width: 5),
                  Text('Сортировка'),
                ],
              ),
            ),
          ),
        ],
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
                    hintText: 'Поиск по названию / описанию…',
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
                      avatar: GlassIcon(
                        _showFavorites ? Glyph.starFilled : Glyph.star,
                        size: 16,
                      ),
                      label: const Text('Избранное'),
                      selected: _showFavorites,
                      onSelected: !_favoritesReady
                          ? null
                          : (value) {
                              setState(() => _showFavorites = value);
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
                            _showFavorites = false;
                            _sort = 'newest';
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
      body: Column(
        children: [
          if ((user?.canManage ?? false) && !_showFavorites)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: GlassIcon(Glyph.add,
                      size: 20, color: Theme.of(context).colorScheme.onPrimary),
                  label: const Text('Новая вакансия'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    alignment: Alignment.center,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(child: Text('Вакансии не найдены'))
                : RefreshIndicator(
                    onRefresh: () => _load(reset: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 100),
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
                                    IconButton(
                                      tooltip: _favoriteIds.contains(v.id)
                                          ? 'Убрать из избранного'
                                          : 'В избранное',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _toggleFavorite(v),
                                      icon: GlassIcon(
                                        _favoriteIds.contains(v.id)
                                            ? Glyph.starFilled
                                            : Glyph.star,
                                        size: 20,
                                        color: _favoriteIds.contains(v.id)
                                            ? const Color(0xFFFFC857)
                                            : null,
                                      ),
                                    ),
                                    if (v.remote)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: StatusChip(
                                            label: 'Удалённо',
                                            color: const Color(0xFF5BC8E8)),
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
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary)),
                                    if (v.city != null) ...[
                                      Text(' · ',
                                          style: TextStyle(
                                              color: appTextColor(context,
                                                  opacity: 0.6))),
                                      GlassIcon(Glyph.pin, size: 15),
                                      Text(v.city!,
                                          style: TextStyle(
                                              color: appTextColor(context,
                                                  opacity: 0.82))),
                                    ],
                                  ],
                                ),
                                if (v.skills.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                      v.skills
                                          .map((e) => e.name)
                                          .take(6)
                                          .join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: appTextColor(context,
                                              opacity: 0.68))),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
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
          for (final city
              in (_items.map((e) => e.city).whereType<String>().toSet().toList()
                ..sort()))
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, city), child: Text(city)),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Все')),
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
      'от 60 000 ₽': 60000,
      'от 100 000 ₽': 100000,
      'от 150 000 ₽': 150000,
      'от 220 000 ₽': 220000,
      'от 300 000 ₽': 300000,
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
