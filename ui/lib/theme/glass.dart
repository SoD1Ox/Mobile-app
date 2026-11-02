/// Staffing workspace design system: warm paper, forest green, restrained
/// lime actions, and a high-contrast dark mode.
///
/// Performance notes:
///  * Scrolling cards never use a live blur. Android, iOS and web use tinted
///    glass surfaces throughout; desktop keeps a small number of bounded blurs.
///  * The background gradient lives in MaterialApp.builder, so it is painted
///    independently from the scrolling page content.
///  * Cards/chips/fields are themed globally (see buildGlassTheme), so every
///    existing widget inherits the glass look without structural changes.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import 'glass_stack.dart' show kGlassRadius;
export 'glass_stack.dart' show kGlassRadius;

// ---------------------------------------------------------------- palette
const Color _accent = Color(0xFFB8E76A); // fresh lime action accent
const Color _forest = Color(0xFF245944);
const Color _accentCoral = Color(0xFFE98263);
const Color _glassFill = Color(0xFFF1F2EB);
const Color _glassBorder = Color(0xFFDDE3D9);

// NOTE: kGlassRadius lives in theme/glass_stack.dart (single source of truth)
// to avoid ambiguous_import when a file imports both theme libraries.

/// Public accent color used by chips / links across screens.
const Color kAccentColor = _forest;

/// Warm coral companion accent (CTA highlights, counters).
const Color kCoralColor = _accentCoral;

/// Dark glass surface used behind dialogs / dropdown menus.
const Color kDialogSurface = Color(0xFFF8F8F3);

/// App-wide Material-3 theme with light editorial surfaces and a dark variant.
ThemeData buildGlassTheme({Brightness brightness = Brightness.dark}) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: _forest,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? _accent : _forest,
    onPrimary: isDark ? const Color(0xFF17231B) : Colors.white,
    secondary: _accentCoral,
    surface: isDark ? const Color(0xFF172320) : const Color(0xFFFCFBF7),
    onSurface: isDark ? const Color(0xFFE8EEE7) : const Color(0xFF1F3029),
  );

  OutlineInputBorder fieldBorder({bool focused = false}) => OutlineInputBorder(
        borderRadius: kGlassRadius,
        borderSide: BorderSide(
          color: focused
              ? (isDark ? _accent : _forest)
              : isDark
                  ? _glassBorder
                  : _glassBorder,
          width: focused ? 1.4 : 1,
        ),
      );

  // Foreground/text colors follow the brightness so the light mint-glass
  // variant stays readable everywhere.
  final fg = isDark ? const Color(0xFFE8EEE7) : const Color(0xFF1F3029);
  final subtle = isDark ? const Color(0xFFB6C4BB) : const Color(0xFF68776D);

  var theme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: isDark ? const Color(0xFF172320) : const Color(0xFFFCFBF7),
    dialogBackgroundColor:
        isDark ? const Color(0xFF1B2925) : const Color(0xFFFCFBF7),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    // cardTheme / dialogTheme intentionally NOT passed to the constructor:
    // their parameter type was renamed CardTheme->CardThemeData and
    // DialogTheme->DialogThemeData in Flutter 3.32+, which breaks compilation
    // across SDK versions. They are applied right after construction instead
    // (copyWith accepts both spellings on old SDKs via dynamic).
    appBarTheme: AppBarTheme(
      backgroundColor:
          isDark ? const Color(0xFF172320) : const Color(0xFFFCFBF7),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: fg,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: fg,
        letterSpacing: 0.2,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: subtle,
      textColor: fg,
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF3D5049) : _glassBorder,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF202F2B) : const Color(0xFFF2F3ED),
      hintStyle: TextStyle(color: subtle.withOpacity(0.6)),
      labelStyle: TextStyle(color: subtle),
      floatingLabelStyle: const TextStyle(color: _accent),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: fieldBorder(),
      focusedBorder: fieldBorder(focused: true),
      errorBorder: OutlineInputBorder(
        borderRadius: kGlassRadius,
        borderSide: const BorderSide(color: Color(0xFFF16A6A)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: kGlassRadius,
        borderSide: const BorderSide(color: Color(0xFFF16A6A), width: 1.4),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
            (isDark ? Color(0xF2123330) : Color(0xF2F5FBF8)).withOpacity(0.98)),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: kGlassRadius)),
        side: const WidgetStatePropertyAll(BorderSide(color: _glassBorder)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: isDark ? _accent : _forest,
        foregroundColor: isDark ? const Color(0xFF17231B) : Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side:
            BorderSide(color: isDark ? const Color(0xFF4C5B53) : _glassBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: isDark ? _accent : _forest,
      foregroundColor: isDark ? const Color(0xFF17231B) : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor:
          isDark ? const Color(0xFF23332E) : const Color(0xFFF0F1EB),
      selectedColor: isDark ? const Color(0xFF465D41) : const Color(0xFFE4F0C8),
      side: BorderSide(color: isDark ? const Color(0xFF3D5049) : _glassBorder),
      labelStyle: TextStyle(color: fg, fontSize: 12.5),
      secondaryLabelStyle: TextStyle(color: fg, fontSize: 12.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          isDark ? const Color(0xFF263630) : const Color(0xFF263B31),
      contentTextStyle: TextStyle(color: fg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      indicatorColor:
          isDark ? const Color(0xFF465D41) : const Color(0xFFE4F0C8),
      backgroundColor: Colors.transparent,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? fg : subtle,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? fg : subtle,
        ),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor:
          isDark ? const Color(0xFF3D5049) : const Color(0xFFDDE3D9),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
    ),
  );

  // Card & dialog glass themes. The parameter type was renamed
  // CardTheme -> CardThemeData and DialogTheme -> DialogThemeData in
  // Flutter 3.32+. To compile on BOTH old (3.24) and new (3.32+) SDKs we
  // don't name either class at all: ThemeData.cardTheme/dialogTheme getters
  // are dynamic-copied via ThemeExtension-free reflection below.
  theme = _applyGlassCard(theme);
  theme = _applyGlassDialog(theme, isDark: isDark);
  return theme;
}

// Builds a card theme using whatever spelling the current SDK exposes.
ThemeData _applyGlassCard(ThemeData base) {
  final Object? ct = base.cardTheme as Object?;
  if (ct == null) return base;
  // copyWith exists on both CardTheme (old) and CardThemeData (new).
  final dynamic copied = (ct as dynamic).copyWith(
    color: base.brightness == Brightness.dark
        ? const Color(0xFF202F2B)
        : const Color(0xFFFEFDF9),
    elevation: 0.0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: kGlassRadius,
      side: BorderSide(
        color: base.brightness == Brightness.dark
            ? const Color(0xFF3D5049)
            : _glassBorder,
      ),
    ),
  );
  return (base as dynamic).copyWith(cardTheme: copied) as ThemeData;
}

ThemeData _applyGlassDialog(ThemeData base, {required bool isDark}) {
  final Object? dt = base.dialogTheme as Object?;
  if (dt == null) return base;
  final fg = isDark ? const Color(0xFFE8EEE7) : const Color(0xFF1F3029);
  final dynamic copied = (dt as dynamic).copyWith(
    backgroundColor: isDark ? const Color(0xFF202F2B) : const Color(0xFFFEFDF9),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      side: BorderSide(
        color: isDark ? const Color(0xFF3D5049) : _glassBorder,
      ),
    ),
    titleTextStyle:
        TextStyle(color: fg, fontSize: 19, fontWeight: FontWeight.w700),
    contentTextStyle: TextStyle(color: fg.withOpacity(0.85), fontSize: 14.5),
  );
  return (base as dynamic).copyWith(dialogTheme: copied) as ThemeData;
}
