import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/brand.dart';

/// Gamya "G" mark: a gold G formed by a road with a centre line and a location pin.
class GamyaMark extends StatelessWidget {
  const GamyaMark({super.key, this.size = 56, this.color = GamyaColors.goldLight});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _MarkPainter(color));
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s * 0.46, s * 0.54);
    final r = s * 0.36;
    final stroke = s * 0.17;
    final gold = Paint()
      ..shader = LinearGradient(colors: [color, GamyaColors.gold, GamyaColors.goldDark], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(Rect.fromCircle(center: c, radius: r + stroke))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    // G arc: from ~ -40° sweeping counter‑clockwise to ~ 250°
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, -math.pi * 0.22, math.pi * 1.62, false, gold);
    // G bar
    final barY = c.dy + r * 0.05;
    canvas.drawLine(Offset(c.dx + r * 0.05, barY), Offset(c.dx + r * 1.0, barY), gold);
    // road centre dashes along the arc
    final dash = Paint()..color = const Color(0xFF1A1A1A)..style = PaintingStyle.stroke..strokeWidth = stroke * 0.16..strokeCap = StrokeCap.round;
    const segments = 9;
    for (var i = 0; i < segments; i++) {
      final a0 = -math.pi * 0.22 + math.pi * 1.62 * (i + 0.15) / segments;
      final a1 = -math.pi * 0.22 + math.pi * 1.62 * (i + 0.6) / segments;
      canvas.drawArc(rect, a0, a1 - a0, false, dash);
    }
    // location pin at top-right
    final pinC = Offset(s * 0.83, s * 0.2);
    final pinR = s * 0.09;
    final pinPaint = Paint()..color = color;
    final path = Path()
      ..moveTo(pinC.dx, pinC.dy + pinR * 2.2)
      ..quadraticBezierTo(pinC.dx - pinR * 1.15, pinC.dy + pinR * 0.6, pinC.dx - pinR, pinC.dy)
      ..arcToPoint(Offset(pinC.dx + pinR, pinC.dy), radius: Radius.circular(pinR), clockwise: true)
      ..quadraticBezierTo(pinC.dx + pinR * 1.15, pinC.dy + pinR * 0.6, pinC.dx, pinC.dy + pinR * 2.2)
      ..close();
    canvas.drawPath(path, pinPaint);
    canvas.drawCircle(pinC, pinR * 0.42, Paint()..color = const Color(0xFF1A1A1A));
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.color != color;
}

/// Full logo lock-up: mark + "G A M Y A" wordmark + "MOBILITY" (+ optional tagline).
class GamyaLogo extends StatelessWidget {
  const GamyaLogo({super.key, this.size = 64, this.onDark = true, this.showTagline = false, this.horizontal = false});
  final double size;
  final bool onDark;
  final bool showTagline;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? GamyaColors.textOnDark : GamyaColors.textPrimary;
    final word = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
      Text('G A M Y A', style: TextStyle(color: textColor, fontSize: size * 0.30, fontWeight: FontWeight.w500, letterSpacing: size * 0.02, height: 1.1)),
      Container(margin: EdgeInsets.only(top: size * 0.04), padding: EdgeInsets.symmetric(horizontal: size * 0.05), decoration: BoxDecoration(border: Border(top: BorderSide(color: GamyaColors.goldLight, width: size * 0.012), bottom: BorderSide(color: GamyaColors.goldLight, width: size * 0.012))), child: Text('MOBILITY', style: TextStyle(color: GamyaColors.goldLight, fontSize: size * 0.13, letterSpacing: size * 0.05, fontWeight: FontWeight.w600, height: 1.5))),
      if (showTagline) Padding(padding: EdgeInsets.only(top: size * 0.12), child: Text(GamyaBrand.tagline, style: TextStyle(color: textColor, fontSize: size * 0.17, fontWeight: FontWeight.w600))),
    ]);
    if (horizontal) return Row(mainAxisSize: MainAxisSize.min, children: [GamyaMark(size: size), SizedBox(width: size * 0.18), word]);
    return Column(mainAxisSize: MainAxisSize.min, children: [GamyaMark(size: size), SizedBox(height: size * 0.06), word]);
  }
}

/// Dark hero block used at the top of mobile auth screens.
class GamyaHeroHeader extends StatelessWidget {
  const GamyaHeroHeader({super.key, this.showTagline = true, this.height = 200});
  final bool showTagline;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
        height: height, width: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [GamyaColors.black, GamyaColors.dark], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(bottom: false, child: Center(child: GamyaLogo(size: height * 0.36, showTagline: showTagline))),
      );
}
