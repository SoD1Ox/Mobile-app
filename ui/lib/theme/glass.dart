/// Glassmorphism (жидкое стекло) design system.
///
/// Performance notes:
///  * Live blur (BackdropFilter) is used only for the persistent bottom nav;
///    everything else fakes frosted glass with translucent gradients — one
///    cheap paint op instead of a per-frame gaussian pass.
///  * The background gradient lives in MaterialApp.builder, so it is painted
///    exactly once per screen and never re-renders on setState.
///  * Cards/chips/fields are themed globally (see buildGlassTheme), so every
///    existing widget inherits the glass look without structural changes.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import 'glass_stack.dart' show kGlassRadius;
export 'glass_stack.dart' show kGlassRadius;

// ---------------------------------------------------------------- palette
// Mint-green + coral design system (dark glass base).
// Background stops are defined in theme/glass_stack.dart (_AuroraBackground).
const Color _accent = Color(0xFF3ED9B8); // mint
const Color _accentCoral = Color(0xFFFF8A66); // warm coral companion
const Color _glassFill = Color(0x1FFFFFFF); // white @ ~12%
const Color _glassBorder = Color(0x33FFFFFF); // white @ 20%

// NOTE: kGlassRadius lives in theme/glass_stack.dart (single source of truth)
// to avoid ambiguous_import when a file imports both theme libraries.

/// Public accent color used by chips / links across screens.
const Color kAccentColor = _accent;

/// Warm coral companion accent (CTA highlights, counters).
const Color kCoralColor = _accentCoral;

/// Dark glass surface used behind dialogs / dropdown menus.
const Color kDialogSurface = Color(0xF210302B);

/// App-wide Material-3 theme built around the glass look.
/// Supports both dark (default) and light mint-glass variants.
ThemeData buildGlassTheme({Brightness brightness = Brightness.dark}) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: _accent,
    brightness: brightness,
  ).copyWith(surface: isDark ? const Color(0xFF0F2925) : const Color(0xFFEFF7F4));

  OutlineInputBorder fieldBorder({bool focused = false}) => OutlineInputBorder(
        borderRadius: kGlassRadius,
        borderSide: BorderSide(
          color: focused ? _accent.withOpacity(0.9) : _glassBorder,
          width: focused ? 1.4 : 1,
        ),
      );

  // Foreground/text colors follow the brightness so the light mint-glass
  // variant stays readable everywhere.
  final fg = isDark ? Colors.white : const Color(0xFF0C2A24);
  final subtle = isDark
      ? const Color(0xCCD9E6E1)
      : const Color(0xB3163A33);

  var theme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    dialogBackgroundColor: isDark
        ? const Color(0xF210302B)
        : const Color(0xF2F5FBF8),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    // cardTheme / dialogTheme intentionally NOT passed to the constructor:
    // their parameter type was renamed CardTheme->CardThemeData and
    // DialogTheme->DialogThemeData in Flutter 3.32+, which breaks compilation
    // across SDK versions. They are applied right after construction instead
    // (copyWith accepts both spellings on old SDKs via dynamic).
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
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
      color: _glassBorder,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _glassFill,
      hintStyle: TextStyle(color: subtle.withOpacity(0.6)),
      labelStyle: TextStyle(color: subtle),
      floatingLabelStyle: const TextStyle(color: _accent),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: const BorderSide(color: _glassBorder),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _accent),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _accent,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _glassFill,
      selectedColor: _accent.withOpacity(0.35),
      side: const BorderSide(color: _glassBorder),
      labelStyle: TextStyle(color: fg, fontSize: 12.5),
      secondaryLabelStyle: TextStyle(color: fg, fontSize: 12.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark
          ? const Color(0xE610302B)
          : const Color(0xE6E4F1EC),
      contentTextStyle: TextStyle(color: fg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      indicatorColor: _accent.withOpacity(0.28),
      backgroundColor: Colors.transparent,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? fg
              : subtle,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? fg : subtle,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _accent,
      linearTrackColor: Color(0x33FFFFFF),
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
    color: _glassFill,
    elevation: 0.0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: kGlassRadius,
      side: BorderSide(color: _glassBorder),
    ),
  );
  return (base as dynamic).copyWith(cardTheme: copied) as ThemeData;
}

ThemeData _applyGlassDialog(ThemeData base, {required bool isDark}) {
  final Object? dt = base.dialogTheme as Object?;
  if (dt == null) return base;
  final fg = isDark ? Colors.white : const Color(0xFF0C2A24);
  final dynamic copied = (dt as dynamic).copyWith(
    backgroundColor:
        isDark ? const Color(0xF210302B) : const Color(0xF2F5FBF8),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      side: BorderSide(color: _glassBorder),
    ),
    titleTextStyle: TextStyle(
        color: fg, fontSize: 19, fontWeight: FontWeight.w700),
    contentTextStyle: TextStyle(color: fg.withOpacity(0.85), fontSize: 14.5),
  );
  return (base as dynamic).copyWith(dialogTheme: copied) as ThemeData;
}
