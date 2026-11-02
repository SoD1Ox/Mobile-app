/// Theme controller: warm light workspace (default) / forest dark variant.
///
/// The choice is persisted in SharedPreferences and applied via
/// ValueListenableBuilder in main.dart, so the whole app (aurora backdrop,
/// glass panels, nav bar) re-skins instantly without a restart.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeController._(ThemeMode initial) : super(initial);

  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final ThemeMode mode;
    if (saved == 'light') {
      mode = ThemeMode.light;
    } else if (saved == 'system') {
      mode = ThemeMode.system;
    } else if (saved == 'dark') {
      mode = ThemeMode.dark;
    } else {
      mode = ThemeMode.light;
    }
    return ThemeController._(mode);
  }

  bool get isDark => value != ThemeMode.light;

  /// Cycles dark -> light -> dark (simple, discoverable toggle).
  void toggle() {
    setMode(value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key,
        switch (value) {
          ThemeMode.light => 'light',
          ThemeMode.system => 'system',
          ThemeMode.dark => 'dark',
        });
  }
}
