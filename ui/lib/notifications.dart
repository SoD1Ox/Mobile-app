/// In-app notification center (bell icon + unread counter).
///
/// Notifications are generated locally from real user actions (moving a case
/// through the funnel, applying to a vacancy, saving entities) and persisted
/// per-user in SharedPreferences, so the history survives restarts.  No fake
/// server feed — every entry reflects something that actually happened.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String title;
  final String body;
  final DateTime at;

  AppNotification({
    required this.title,
    required this.body,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  Map<String, dynamic> toJson() =>
      {'title': title, 'body': body, 'at': at.toIso8601String()};

  factory AppNotification.fromJson(Map<String, dynamic> j) =>
      AppNotification(
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}

class NotificationStore extends ChangeNotifier {
  static const _maxItems = 50;

  final List<AppNotification> _items = [];
  int _unread = 0;
  bool _loaded = false;

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _unread;

  Future<void> loadFor(String username) async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('notifications_$username');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList();
        _items
          ..clear()
          ..addAll(list);
      } catch (_) {/* corrupted cache — start fresh */}
    }
    final seenAt = prefs.getInt('notifications_seen_$username');
    _unread = _items
        .where((n) => seenAt == null || n.at.millisecondsSinceEpoch > seenAt)
        .length;
    notifyListeners();
  }

  void add(String title, String body) {
    _items.insert(0, AppNotification(title: title, body: body));
    if (_items.length > _maxItems) _items.removeRange(_maxItems, _items.length);
    _unread++;
    notifyListeners();
    _persist();
  }

  void markAllSeen() {
    if (_unread == 0) return;
    _unread = 0;
    notifyListeners();
    SharedPreferences.getInstance().then(
        (prefs) => prefs.setInt('notifications_seen_${_lastUser}',
            DateTime.now().millisecondsSinceEpoch));
  }

  void clear() {
    _items.clear();
    _unread = 0;
    notifyListeners();
    _persist();
  }

  String _lastUser = '';

  /// Remembers the active user for persistence keys.
  set currentUser(String v) => _lastUser = v;

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'notifications_$_lastUser', jsonEncode(_items.map((e) => e.toJson()).toList()));
  }
}
