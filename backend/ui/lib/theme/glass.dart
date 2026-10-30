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
const Color _bgTop = Color(0xFF101A33);
const Color _bgMid = Color(0xFF16294E);
const Color _bgBottom = Color(0xFF0B1224);
const Color _accent = Color(0xFF5B8CFF);
const Color _glassFill = Color(0x1FFFFFFF); // white @ ~12%
const Color _glassBorder = Color(0x33FFFFFF); // white @ 20%

const BorderRadius kGlassRadius = BorderRadius.all(Radius.circular(18));

/// App-wide dark Material-3 theme built around the glass look.
ThemeData buildGlassTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _accent,
    brightness: Brightness.dark,
  ).copyWith(surface: const Color(0xFF14213D));

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
    dialogBackgroundColor: const Color(0xF2182A4D),
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
      iconColor: Color(0xC7D3EA),
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
        borderSide: const BorderSide(color: Color(0xFFFF7A7A)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: kGlassRadius,
        borderSide: const BorderSide(color: Color(0xFFFF7A7A), width: 1.4),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor:
            WidgetStatePropertyAll(Color(0xF216294E).withOpacity(0.98)),
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
      backgroundColor: const Color(0xE6182A4D),
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

  // Card/dialog themes are applied AFTER construction via copyWith.
  // Rationale: the ThemeData constructor parameter types were renamed
  // CardTheme -> CardThemeData and DialogTheme -> DialogThemeData in
  // Flutter 3.32+, so passing them inline breaks compilation on one of the
  // SDK generations.  copyWith accepts *either* spelling depending on SDK:
  //   - on >=3.32 it takes CardThemeData/DialogThemeData;
  //   - on <3.32  it takes CardTheme/DialogTheme.
  // On modern SDKs `CardTheme`/`DialogTheme` are deprecated typedef aliases
  // of the *Data classes, so constructing with the legacy names type-checks
  // everywhere.  If the analyzer/compiler rejects a name on your exact SDK,
  // replace it with the *Data variant (CardThemeData / DialogThemeData) —
  // both refer to the same class on 3.32+.
  final glassCard = _buildGlassCardTheme();
  final glassDialog = _buildGlassDialogTheme();
  return theme.copyWith(cardTheme: glassCard, dialogTheme: glassDialog);
}

// ignore: deprecated_member_use
dynamic _buildGlassCardTheme() => const CardThemeData(
      color: _glassFill,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: kGlassRadius,
        side: BorderSide(color: _glassBorder),
      ),
    );

// ignore: deprecated_member_use
dynamic _buildGlassDialogTheme() => DialogThemeData(
      backgroundColor: const Color(0xF2182A4D),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        side: BorderSide(color: _glassBorder),
      ),
      titleTextStyle: const TextStyle(
          color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
      contentTextStyle: TextStyle(
          color: Colors.white.withOpacity(0.85), fontSize: 14.5),
    );

// ------------------------------------------------------------- background
/// Deep blue gradient + soft glow blobs. `const` decorations => zero rebuild
/// cost; painted once behind every screen via MaterialApp.builder.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  static const List<BoxShadow> _glow = [
    BoxShadow(
        color: Color(0x3D5B8CFF),
        blurRadius: 140,
        spreadRadius: 40,
        offset: Offset(-120, -80)),
    BoxShadow(
        color: Color(0x2E7BD76F),
        blurRadius: 160,
        spreadRadius: 30,
        offset: Offset(160, 220)),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgTop, _bgMid, _bgBottom],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  width: 1,
                  height: 1,
                  alignment: Alignment.topLeft,
                  decoration: const BoxDecoration(boxShadow: _glow),
                ),
              ),
            ),
            child,
          ],
        ),
      );
}

/// Real backdrop-blur glass panel. Used ONLY for the persistent bottom
/// navigation bar (a single fixed-size layer) — never inside scrolling rows.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double blur;

  const GlassPanel({super.key, required this.child, this.blur = 18});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _glassBorder),
            ),
            child: child,
          ),
        ),
      );
}

