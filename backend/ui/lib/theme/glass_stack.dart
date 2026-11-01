/// True "liquid glass" backdrop stack.
///
/// Architecture:
///  * [GlassRoot] is installed once in `MaterialApp.builder`.  It paints the
///    aurora background inside a [Stack] and hosts a single app-wide frosted
///    overlay layer above the route tree (`RepaintBoundary` + [ValueNotifier]).
///  * A screen wraps its body with [FrostedHeader]; the header strip is then
///    rendered into that overlay OUTSIDE the scrolling content — rows visually
///    slide under real gaussian blur while it costs exactly ONE BackdropFilter
///    per screen (never per list row).
///  * [RealGlassCard] = real BackdropFilter for detail screens / hero cards
///    (bounded count — safe even on web CanvasKit).
///  * [GlassListCard] (widgets/common.dart) stays gradient-frosted for long
///    scrolling lists: N live blurs would kill FPS; over a static backdrop it
///    is visually identical to real blur.
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------- palette
const Color kAccent = Color(0xFF3ED9B8); // mint
const Color kCoral = Color(0xFFFF8A66); // warm coral
const Color kGlassBorder = Color(0x33FFFFFF);
const BorderRadius kGlassRadius = BorderRadius.all(Radius.circular(18));

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
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                height: top + data.height,
                padding: EdgeInsets.only(top: top),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: kGlassBorder)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.10),
                      Colors.white.withOpacity(0.04),
                    ],
                  ),
                ),
                child: Builder(builder: data.builder),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Deep-blue aurora: gradient + soft glow blobs.  `const` decorations →
/// zero rebuild cost.
class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  static const List<BoxShadow> _glow = [
    BoxShadow(
        color: Color(0x3D3ED9B8),
        blurRadius: 140,
        spreadRadius: 40,
        offset: Offset(-120, -80)),
    BoxShadow(
        color: Color(0x2EFF8A66),
        blurRadius: 160,
        spreadRadius: 30,
        offset: Offset(160, 220)),
    BoxShadow(
        color: Color(0x226FE3C4),
        blurRadius: 120,
        spreadRadius: 20,
        offset: Offset(0, -260)),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C1F1D), Color(0xFF123330), Color(0xFF081413)],
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
          ],
        ),
      );
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
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: ClipRRect(
          borderRadius: kGlassRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: kGlassRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.14),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: kGlassRadius,
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Persistent bottom-nav glass (kept from the original design system).
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
              border: Border.all(color: kGlassBorder),
            ),
            child: child,
          ),
        ),
      );
}
