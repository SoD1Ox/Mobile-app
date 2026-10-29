/// Custom vector icon set (hand-painted paths, no Material Icons / emoji).
///
/// Every glyph is drawn with a single [Path] + stroke — cheap to rasterize,
/// scales crisply at any size and keeps the app free of the icon font.
library;

import 'package:flutter/material.dart';

enum Glyph {
  add,
  back,
  chevronLeft,
  chevronRight,
  close,
  delete,
  edit,
  eye,
  eyeOff,
  filter,
  home,
  lock,
  logout,
  people,
  person,
  plusCircle,
  refresh,
  save,
  search,
  send,
  server,
  task,
  folder,
  building,
  dashboard,
  list,
}

class GlassIcon extends StatelessWidget {
  final Glyph glyph;
  final double size;
  final Color? color;

  const GlassIcon(this.glyph,
      {super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _GlyphPainter(glyph, color ?? Theme.of(context).iconTheme.color ?? Colors.white),
      );
}

class _GlyphPainter extends CustomPainter {
  final Glyph glyph;
  final Color color;

  _GlyphPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24; // design grid is 24x24
    canvas.scale(s);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (glyph) {
      case Glyph.add:
        _line(canvas, stroke, Offset(12, 5), Offset(12, 19));
        _line(canvas, stroke, Offset(5, 12), Offset(19, 12));
      case Glyph.plusCircle:
        canvas.drawCircle(const Offset(12, 12), 8.2, stroke);
        _line(canvas, stroke, const Offset(12, 8.6), const Offset(12, 15.4));
        _line(canvas, stroke, const Offset(8.6, 12), const Offset(15.4, 12));
      case Glyph.back:
        _line(canvas, stroke, const Offset(15, 5), const Offset(8, 12));
        _line(canvas, stroke, const Offset(8, 12), const Offset(15, 19));
        _line(canvas, stroke, const Offset(8, 12), const Offset(20, 12));
      case Glyph.chevronLeft:
        _line(canvas, stroke, const Offset(14.5, 5.5), const Offset(8.5, 12));
        _line(canvas, stroke, const Offset(8.5, 12), const Offset(14.5, 18.5));
      case Glyph.chevronRight:
        _line(canvas, stroke, const Offset(9.5, 5.5), const Offset(15.5, 12));
        _line(canvas, stroke, const Offset(15.5, 12), const Offset(9.5, 18.5));
      case Glyph.close:
        _line(canvas, stroke, const Offset(6, 6), const Offset(18, 18));
        _line(canvas, stroke, const Offset(18, 6), const Offset(6, 18));
      case Glyph.delete:
        _path(canvas, stroke, (p) {
          p.moveTo(5, 7);
          p.lineTo(6.2, 19.4);
          p.quadraticBezierTo(6.3, 20.5, 7.4, 20.5);
          p.lineTo(16.6, 20.5);
          p.quadraticBezierTo(17.7, 20.5, 17.8, 19.4);
          p.lineTo(19, 7);
        });
        _line(canvas, stroke, const Offset(3.5, 7), const Offset(20.5, 7));
        _path(canvas, stroke, (p) {
          p.moveTo(9.3, 7);
          p.lineTo(9.3, 4.8);
          p.quadraticBezierTo(9.3, 3.8, 10.3, 3.8);
          p.lineTo(13.7, 3.8);
          p.quadraticBezierTo(14.7, 3.8, 14.7, 4.8);
          p.lineTo(14.7, 7);
        });
        _line(canvas, stroke, const Offset(10.2, 10.5), const Offset(10.5, 17.5));
        _line(canvas, stroke, const Offset(13.8, 10.5), const Offset(13.5, 17.5));
      case Glyph.edit:
        _path(canvas, stroke, (p) {
          p.moveTo(4.5, 19.5);
          p.lineTo(5.6, 15.4);
          p.lineTo(16.2, 4.8);
          p.quadraticBezierTo(17.6, 3.4, 19, 4.8);
          p.quadraticBezierTo(20.4, 6.2, 19, 7.6);
          p.lineTo(8.4, 18.2);
          p.close();
        });
        _line(canvas, stroke, const Offset(14.4, 6.6), const Offset(17.2, 9.4));
      case Glyph.eye:
        _path(canvas, stroke, (p) {
          p.moveTo(2.5, 12);
          p.quadraticBezierTo(7, 5.2, 12, 5.2);
          p.quadraticBezierTo(17, 5.2, 21.5, 12);
          p.quadraticBezierTo(17, 18.8, 12, 18.8);
          p.quadraticBezierTo(7, 18.8, 2.5, 12);
        });
        canvas.drawCircle(const Offset(12, 12), 3.1, stroke);
        canvas.drawCircle(const Offset(12, 12), 1.1, fill);
      case Glyph.eyeOff:
        _path(canvas, stroke, (p) {
          p.moveTo(4, 8.2);
          p.quadraticBezierTo(7.6, 5.2, 12, 5.2);
          p.quadraticBezierTo(17, 5.2, 21.5, 12);
          p.quadraticBezierTo(19.6, 14.7, 17.2, 16.6);
        });
        _path(canvas, stroke, (p) {
          p.moveTo(9.6, 17.2);
          p.quadraticBezierTo(7.2, 15.9, 5.4, 14.2);
          p.quadraticBezierTo(3.4, 13, 2.5, 12);
        });
        _line(canvas, stroke, const Offset(4, 4), const Offset(20, 20));
      case Glyph.filter:
        _path(canvas, stroke, (p) {
          p.moveTo(4, 5.5);
          p.lineTo(20, 5.5);
          p.moveTo(6.8, 12);
          p.lineTo(17.2, 12);
          p.moveTo(9.5, 18.5);
          p.lineTo(14.5, 18.5);
        });
        canvas.drawCircle(const Offset(9.5, 5.5), 2.1, fill);
        canvas.drawCircle(const Offset(14.5, 12), 2.1, fill);
        canvas.drawCircle(const Offset(12, 18.5), 2.1, fill);
      case Glyph.home:
        _path(canvas, stroke, (p) {
          p.moveTo(4, 10.5);
          p.lineTo(12, 4);
          p.lineTo(20, 10.5);
          p.moveTo(6, 9.5);
          p.lineTo(6, 19.5);
          p.quadraticBezierTo(6, 20.3, 6.8, 20.3);
          p.lineTo(17.2, 20.3);
          p.quadraticBezierTo(18, 20.3, 18, 19.5);
          p.lineTo(18, 9.5);
        });
        _path(canvas, stroke, (p) {
          p.moveTo(10, 20.3);
          p.lineTo(10, 14);
          p.lineTo(14, 14);
          p.lineTo(14, 20.3);
        });
      case Glyph.lock:
        _path(canvas, stroke, (p) {
          p.moveTo(5.5, 11);
          p.lineTo(5.5, 19);
          p.quadraticBezierTo(5.5, 20.2, 6.7, 20.2);
          p.lineTo(17.3, 20.2);
          p.quadraticBezierTo(18.5, 20.2, 18.5, 19);
          p.lineTo(18.5, 11);
          p.quadraticBezierTo(18.5, 9.8, 17.3, 9.8);
          p.lineTo(6.7, 9.8);
          p.quadraticBezierTo(5.5, 9.8, 5.5, 11);
        });
        _path(canvas, stroke, (p) {
          p.moveTo(8.3, 9.8);
          p.lineTo(8.3, 7);
          p.quadraticBezierTo(8.3, 3.6, 12, 3.6);
          p.quadraticBezierTo(15.7, 3.6, 15.7, 7);
          p.lineTo(15.7, 9.8);
        });
        canvas.drawCircle(const Offset(12, 14.4), 1.5, fill);
        _line(canvas, stroke, const Offset(12, 15.6), const Offset(12, 17.4));
      case Glyph.logout:
        _path(canvas, stroke, (p) {
          p.moveTo(14, 4.5);
          p.lineTo(6.5, 4.5);
          p.quadraticBezierTo(4.5, 4.5, 4.5, 6.5);
          p.lineTo(4.5, 17.5);
          p.quadraticBezierTo(4.5, 19.5, 6.5, 19.5);
          p.lineTo(14, 19.5);
        });
        _line(canvas, stroke, const Offset(10, 12), const Offset(21, 12));
        _line(canvas, stroke, const Offset(17.5, 8.5), const Offset(21, 12));
        _line(canvas, stroke, const Offset(17.5, 15.5), const Offset(21, 12));
      case Glyph.people:
        canvas.drawCircle(const Offset(9, 8), 3.4, stroke);
        _path(canvas, stroke, (p) {
          p.moveTo(3, 19.5);
          p.quadraticBezierTo(3.4, 14.2, 9, 14.2);
          p.quadraticBezierTo(14.6, 14.2, 15, 19.5);
        });
        _path(canvas, stroke, (p) {
          p.moveTo(15.5, 4.9);
          p.quadraticBezierTo(18.6, 5.6, 18.6, 8.6);
          p.quadraticBezierTo(18.6, 11.1, 16.6, 12.1);
        });
        _path(canvas, stroke, (p) {
          p.moveTo(17.6, 14.4);
          p.quadraticBezierTo(20.6, 15.4, 21, 19.5);
        });
      case Glyph.person:
        canvas.drawCircle(const Offset(12, 8), 3.7, stroke);
        _path(canvas, stroke, (p) {
          p.moveTo(4.8, 20);
          p.quadraticBezierTo(5.4, 14.2, 12, 14.2);
          p.quadraticBezierTo(18.6, 14.2, 19.2, 20);
        });
      case Glyph.refresh:
        _path(canvas, stroke, (p) {
          p.addArc(
              Rect.fromLTWH(4.5, 4.5, 15, 15), -1.9, 4.4); // open arc ring
        });
        _path(canvas, stroke, (p) {
          p.moveTo(18.6, 3.6);
          p.lineTo(19.6, 7.4);
          p.lineTo(15.8, 6.6);
        });
      case Glyph.save:
        _path(canvas, stroke, (p) {
          p.moveTo(5, 4.5);
          p.lineTo(17, 4.5);
          p.quadraticBezierTo(18.6, 4.5, 19.5, 6.1);
          p.lineTo(19.5, 19);
          p.quadraticBezierTo(19.5, 20, 18.5, 20);
          p.lineTo(5.5, 20);
          p.quadraticBezierTo(4.5, 20, 4.5, 19);
          p.lineTo(4.5, 5.5);
          p.quadraticBezierTo(4.5, 4.5, 5, 4.5);
        });
        _path(canvas, stroke, (p) {
          p.moveTo(8, 4.6);
          p.lineTo(8, 9.2);
          p.lineTo(15.5, 9.2);
          p.lineTo(15.5, 4.6);
        });
        _path(canvas, stroke, (p) {
          p.moveTo(8.2, 20);
          p.lineTo(8.2, 14.4);
          p.lineTo(15.8, 14.4);
          p.lineTo(15.8, 20);
        });
      case Glyph.search:
        canvas.drawCircle(const Offset(10.5, 10.5), 6.2, stroke);
        _line(canvas, stroke, const Offset(15.2, 15.2), const Offset(20, 20));
      case Glyph.send:
        _path(canvas, stroke, (p) {
          p.moveTo(3.5, 12);
          p.lineTo(20.5, 4.5);
          p.lineTo(14.5, 20.5);
          p.lineTo(11, 13.5);
          p.close();
        });
        _line(canvas, stroke, const Offset(11, 13.5), const Offset(20.5, 4.5));
      case Glyph.server:
        _path(canvas, stroke, (p) {
          p.addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTWH(3.5, 4, 17, 6.5), const Radius.circular(2)));
        });
        _path(canvas, stroke, (p) {
          p.addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTWH(3.5, 13.5, 17, 6.5), const Radius.circular(2)));
        });
        canvas.drawCircle(const Offset(7.2, 7.2), 0.9, fill);
        canvas.drawCircle(const Offset(7.2, 16.7), 0.9, fill);
        _line(canvas, stroke, const Offset(14.5, 7.2), const Offset(17.5, 7.2));
        _line(canvas, stroke, const Offset(14.5, 16.7), const Offset(17.5, 16.7));
      case Glyph.task:
        _path(canvas, stroke, (p) {
          p.addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTWH(4, 3.5, 16, 17), const Radius.circular(2.6)));
        });
        _path(canvas, stroke, (p) {
          p.moveTo(7.6, 12.4);
          p.lineTo(10.4, 15.2);
          p.lineTo(16.4, 8.6);
        });
        _line(canvas, stroke, const Offset(8, 6.8), const Offset(16, 6.8));
      case Glyph.folder:
        _path(canvas, stroke, (p) {
          p.moveTo(3.5, 7.5);
          p.quadraticBezierTo(3.5, 5.5, 5.5, 5.5);
          p.lineTo(9.8, 5.5);
          p.lineTo(11.6, 7.8);
          p.lineTo(18.5, 7.8);
          p.quadraticBezierTo(20.5, 7.8, 20.5, 9.6);
          p.lineTo(20.5, 18);
          p.quadraticBezierTo(20.5, 20, 18.5, 20);
          p.lineTo(5.5, 20);
          p.quadraticBezierTo(3.5, 20, 3.5, 18);
          p.close();
        });
      case Glyph.building:
        _path(canvas, stroke, (p) {
          p.addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTWH(5, 3.5, 14, 17), const Radius.circular(1.8)));
        });
        canvas.drawRect(const Rect.fromLTWH(8, 6.5, 2.6, 2.6), stroke);
        canvas.drawRect(const Rect.fromLTWH(13.4, 6.5, 2.6, 2.6), stroke);
        canvas.drawRect(const Rect.fromLTWH(8, 11.5, 2.6, 2.6), stroke);
        canvas.drawRect(const Rect.fromLTWH(13.4, 11.5, 2.6, 2.6), stroke);
        _path(canvas, stroke, (p) {
          p.moveTo(10.2, 20.5);
          p.lineTo(10.2, 16.6);
          p.lineTo(13.8, 16.6);
          p.lineTo(13.8, 20.5);
        });
      case Glyph.dashboard:
        _path(canvas, stroke, (p) {
          p.addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTWH(3.5, 3.5, 7.5, 7.5), const Radius.circular(2)));
        });
        _path(canvas, stroke, (p) {
          p.addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTWH(13, 3.5, 7.5, 7.5), const Radius.circular(2)));
        });
        _path(canvas, stroke, (p) {
          p.addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTWH(3.5, 13, 7.5, 7.5), const Radius.circular(2)));
        });
        _path(canvas, stroke, (p) {
          p.addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTWH(13, 13, 7.5, 7.5), const Radius.circular(2)));
        });
      case Glyph.list:
        _path(canvas, stroke, (p) {
          p.moveTo(8.5, 6);
          p.lineTo(20, 6);
          p.moveTo(8.5, 12);
          p.lineTo(20, 12);
          p.moveTo(8.5, 18);
          p.lineTo(20, 18);
        });
        canvas.drawCircle(const Offset(4.6, 6), 1.3, fill);
        canvas.drawCircle(const Offset(4.6, 12), 1.3, fill);
        canvas.drawCircle(const Offset(4.6, 18), 1.3, fill);
    }
  }

  void _line(Canvas c, Paint p, Offset a, Offset b) => c.drawLine(a, b, p);

  void _path(Canvas c, Paint p, void Function(Path) build) {
    final path = Path();
    build(path);
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

/// Small round glass button hosting a [GlassIcon] — replaces IconButton+Icon.
class GlassIconButton extends StatelessWidget {
  final Glyph glyph;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final String? tooltip;

  const GlassIconButton(this.glyph,
      {super.key, this.onPressed, this.size = 22, this.color, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: GlassIcon(glyph, size: size, color: color),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
