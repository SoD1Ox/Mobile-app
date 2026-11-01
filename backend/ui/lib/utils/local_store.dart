/// Local (device-side) storage helpers built on SharedPreferences:
///  * [FavoritesStore] — "избранное" for vacancies (our feature #2):
///    recruiters can star positions and see only starred ones offline-fast;
///  * [RecentSearches] — last search queries per entity, shown as chips.
library;

import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore {
  static const _key = 'fav_vacancies';

  Future<Set<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? [])
        .map((e) => int.tryParse(e) ?? -1)
        .where((e) => e > 0)
        .toSet();
  }

  Future<void> toggle(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final cur = (prefs.getStringList(_key) ?? []).toSet();
    final s = id.toString();
    if (cur.contains(s)) {
      cur.remove(s);
    } else {
      cur.add(s);
    }
    await prefs.setStringList(_key, cur.toList());
  }
}

class RecentSearches {
  static const _prefix = 'recent_search_';
  static const _max = 6;

  Future<List<String>> load(String entity) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_prefix$entity') ?? [];
  }

  Future<void> push(String entity, String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList('$_prefix$entity') ?? []).toList();
    list.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    list.insert(0, q);
    if (list.length > _max) list.removeRange(_max, list.length);
    await prefs.setStringList('$_prefix$entity', list);
  }
}
