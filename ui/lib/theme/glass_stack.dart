/// Lightweight app background and reusable surfaces.
///
/// Architecture:
///  * [GlassRoot] is installed once in `MaterialApp.builder`.  It paints the
///    aurora background inside a [Stack] and hosts a single app-wide frosted
///    overlay layer above the route tree (`RepaintBoundary` + [ValueNotifier]).
///  * A screen wraps its body with [FrostedHeader]; the header strip is then
///    rendered into that overlay OUTSIDE the scrolling content — rows visually
///    slide under real gaussian blur while it costs exactly ONE BackdropFilter
///    per screen (never per list row).
///  * [RealGlassCard] uses a bounded live blur on desktop and a tinted surface
///    on mobile; long lists always use the cheaper tinted treatment.
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------- palette
const Color kAccent = Color(0xFFB8E76A);
const Color kCoral = Color(0xFFE98263);
const Color kGlassBorder = Color(0xFFDDE3D9);
const BorderRadius kGlassRadius = BorderRadius.all(Radius.circular(20));

/// Gaussian backdrop filters are expensive on phones, especially while a list
/// scrolls. Keep the live effect for desktop, and use tinted surfaces on mobile.
bool get _useLiveBackdropBlur =>
    !kIsWeb &&
    defaultTargetPlatform != TargetPlatform.android &&
    defaultTargetPlatform != TargetPlatform.iOS;

class _GlassPanelData {
  final Object key;
  final Widget Function(BuildContext) builder;
  final double height;
  const _GlassPanelData(this.key, this.height, this.builder);
}

/// App-wide notifier holding the currently visible frosted panel.
class GlassOverlayState {
  static final ValueNotifier<_GlassPanelData?> active =
      ValueNotifier<_GlassPanelData?>(null);
}

/// Wraps a screen body (put it INSIDE the Scaffold body so it inherits the
/// page MediaQuery/ScaffoldMessenger).  Its [builder] returns a fixed-height
/// strip painted into the app-level glass overlay (real blur) instead of
/// inside the page, so scrolling content passes beneath it.
class FrostedHeader extends StatefulWidget {
  /// Identity of the owning screen (use the State object as owner).
  final Object owner;
  final double height; // excluding status bar
  final Widget Function(BuildContext context) builder;

  const FrostedHeader({
    super.key,
    required this.owner,
    required this.height,
    required this.builder,
    this.body = const SizedBox.shrink(),
  });

  /// The screen content rendered in-place (under the floating strip).
  final Widget body;

  @override
  State<FrostedHeader> createState() => _FrostedHeaderState();
}

class _FrostedHeaderState extends State<FrostedHeader> {
  @override
  void initState() {
    super.initState();
    _publish();
  }

  @override
  void didUpdateWidget(covariant FrostedHeader old) {
    super.didUpdateWidget(old);
    if (!identical(old.builder, widget.builder) ||
        old.height != widget.height ||
        old.owner != widget.owner) {
      _publish();
    }
  }

  void _publish() {
    GlassOverlayState.active.value =
        _GlassPanelData(widget.owner, widget.height, widget.builder);
  }

  @override
  void dispose() {
    // Only clear when this screen really goes away AND still owns the slot
    // (a pushed route republishes before the old one pops-disposes).
    final cur = GlassOverlayState.active.value;
    if (cur != null && cur.key == widget.owner) {
      GlassOverlayState.active.value = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.body;
}

/// App-level background + glass overlay host.  Put in MaterialApp.builder.
class GlassRoot extends StatelessWidget {
  final Widget child;

  const GlassRoot({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _AuroraBackground(),
        // Page tree sits above the aurora but BELOW the glass overlay, so
        // rows visibly blur while sliding under the frosted header.
        child,
        // Live glass overlay layer (repaints only when its content changes).
        RepaintBoundary(
          child: ValueListenableBuilder<_GlassPanelData?>(
            valueListenable: GlassOverlayState.active,
            builder: (_, data, __) => data == null
                ? const SizedBox.shrink()
                : _OverlayHost(data: data),
          ),
        ),
      ],
    );
  }
}

class _OverlayHost extends StatelessWidget {
  final _GlassPanelData data;

  const _OverlayHost({required this.data});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final header = Container(
      height: top + data.height,
      padding: EdgeInsets.only(top: top),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF3D5049) : const Color(0xFFDDE3D9),
          ),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _useLiveBackdropBlur
              ? const [Color(0x16FFFFFF), Color(0x08FFFFFF)]
              : isDark
                  ? const [Color(0xF51B2925), Color(0xF2172320)]
                  : const [Color(0xF8FCFBF7), Color(0xF1F4F3EC)],
        ),
      ),
      child: Builder(builder: data.builder),
    );
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: ClipRect(
            child: _useLiveBackdropBlur
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: header,
                  )
                : header,
          ),
        ),
      ],
    );
  }
}

/// Subtle gradient background. Large blurred shadow blobs caused heavy GPU
/// work on mobile, so the backdrop stays flat and inexpensive there.
class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF14211D), Color(0xFF1B2D27), Color(0xFF111A17)]
              : const [Color(0xFFF5F3EC), Color(0xFFF0F2E7), Color(0xFFF8F7F2)],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

/// Real backdrop-blur glass card — for detail screens, dashboards, dialogs.
/// Keep the number of simultaneously visible instances small (≤ ~6).
class RealGlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double blur;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const RealGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.blur = 16,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: kGlassRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _useLiveBackdropBlur
              ? const [Color(0x32FFFFFF), Color(0x14FFFFFF)]
              : isDark
                  ? const [Color(0xFF202F2B), Color(0xFF1B2925)]
                  : const [Color(0xFFFEFDF9), Color(0xFFF7F7F1)],
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF3D5049) : const Color(0xFFDDE3D9),
        ),
        boxShadow: _useLiveBackdropBlur
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.16 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : const [],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: kGlassRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    final card = _useLiveBackdropBlur
        ? ClipRRect(
            borderRadius: kGlassRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: surface,
            ),
          )
        : surface;
    return Padding(padding: margin, child: card);
  }
}

/// Persistent bottom-nav surface shared across the app.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double blur;

  const GlassPanel({super.key, required this.child, this.blur = 18});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface
            .withOpacity(_useLiveBackdropBlur ? 0.88 : 1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF3D5049) : const Color(0xFFDDE3D9),
        ),
        boxShadow: _useLiveBackdropBlur
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.18 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: child,
    );
    if (!_useLiveBackdropBlur) return surface;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: surface,
      ),
    );
  }
}
