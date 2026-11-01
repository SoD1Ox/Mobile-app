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

// ---------------------------------------------------------------- palette
// Mint-green + coral design system (dark glass base).
// Background stops are defined in theme/glass_stack.dart (_AuroraBackground).
const Color _accent = Color(0xFF3ED9B8); // mint
const Color _accentCoral = Color(0xFFFF8A66); // warm coral companion
const Color _glassFill = Color(0x1FFFFFFF); // white @ ~12%
const Color _glassBorder = Color(0x33FFFFFF); // white @ 20%

const BorderRadius kGlassRadius = BorderRadius.all(Radius.circular(18));

/// Public accent color used by chips / links across screens.
const Color kAccentColor = _accent;

/// Warm coral companion accent (CTA highlights, counters).
const Color kCoralColor = _accentCoral;

/// Dark glass surface used behind dialogs / dropdown menus.
const Color kDialogSurface = Color(0xF210302B);

/// App-wide dark Material-3 theme built around the glass look.
ThemeData buildGlassTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _accent,
    brightness: Brightness.dark,
  ).copyWith(surface: const Color(0xFF0F2925));

  OutlineInputBorder fieldBorder({bool focused = false}) => OutlineInputBorder(
        borderRadius: kGlassRadius,
        borderSide: BorderSide(
          color: focused ? _accent.withOpacity(0.9) : _glassBorder,
          width: focused ? 1.4 : 1,
        ),
      );

  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    dialogBackgroundColor: const Color(0xF210302B),
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
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.2,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xCCD9E6E1),
      textColor: Colors.white,
    ),
    dividerTheme: DividerThemeData(
      color: _glassBorder,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _glassFill,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
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
        backgroundColor:
            WidgetStatePropertyAll(Color(0xF2123330).withOpacity(0.98)),
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
        foregroundColor: Colors.white,
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
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12.5),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 12.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xE610302B),
      contentTextStyle: const TextStyle(color: Colors.white),
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
              ? Colors.white
              : Colors.white.withOpacity(0.6),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white.withOpacity(0.6),
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

  // Card & dialog glass themes (CardThemeData spelling exists on SDK>=3.32;
  // this project targets 3.24 where CardTheme/DialogTheme are the classes).
  return theme.copyWith(
    cardTheme: const CardTheme(
      color: _glassFill,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: kGlassRadius,
        side: BorderSide(color: _glassBorder),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xF210302B),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        side: BorderSide(color: _glassBorder),
      ),
      titleTextStyle: const TextStyle(
          color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
      contentTextStyle: TextStyle(
          color: Colors.white.withOpacity(0.85), fontSize: 14.5),
    ),
  );
}
