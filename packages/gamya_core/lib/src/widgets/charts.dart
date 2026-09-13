import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ChartSlice {
  const ChartSlice({required this.label, required this.value, required this.color});
  final String label; final num value; final Color color;
}

/// Donut with centre total and a legend (Platform Wise Bookings, Trip Status …).
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.centerLabel, this.size = 130, this.legendRight = true, this.showPct = true, this.totalLabel = 'Total'});
  final List<ChartSlice> slices; final String? centerLabel; final double size; final bool legendRight; final bool showPct; final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<num>(0, (s, x) => s + x.value);
    final donut = SizedBox(width: size, height: size, child: CustomPaint(painter: _DonutPainter(slices, total), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(totalLabel, style: const TextStyle(fontSize: 11, color: GamyaColors.textSecondary)), Text(centerLabel ?? '$total', style: TextStyle(fontSize: size * 0.17, fontWeight: FontWeight.w700))]))));
    final legend = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final s in slices) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 11, height: 11, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 8),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 120), child: Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: GamyaColors.textPrimary))), const SizedBox(width: 10),
        Text(showPct && total > 0 ? '${s.value} (${(s.value / total * 100).round()}%)' : '${s.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ])),
    ]);
    if (!legendRight) return Column(mainAxisSize: MainAxisSize.min, children: [donut, const SizedBox(height: 12), legend]);
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [donut, const SizedBox(width: 18), Flexible(child: legend)]);
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.total);
  final List<ChartSlice> slices; final num total;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(size.width * 0.12);
    final stroke = size.width * 0.2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke;
    if (total <= 0) { canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = GamyaColors.neutralBg); return; }
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * math.pi * 2;
      canvas.drawArc(rect, start, sweep - 0.03, false, paint..color = s.color);
      start += sweep;
    }
  }
  @override
  bool shouldRepaint(covariant _DonutPainter o) => o.slices != slices || o.total != total;
}

class BarGroup {
  const BarGroup({required this.label, required this.values});
  final String label; final List<num> values; // stacked segments
  num get total => values.fold(0, (s, v) => s + v);
}

/// Stacked (or single) vertical bars with axis labels and legend.
class StackedBarChart extends StatelessWidget {
  const StackedBarChart({super.key, required this.groups, required this.colors, this.legend = const [], this.height = 180, this.barWidthFactor = 0.5, this.showValues = false});
  final List<BarGroup> groups; final List<Color> colors; final List<String> legend; final double height; final double barWidthFactor; final bool showValues;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (legend.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Wrap(spacing: 14, children: [for (var i = 0; i < legend.length; i++) Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: colors[i % colors.length]), const SizedBox(width: 5), Text(legend[i], style: const TextStyle(fontSize: 11.5, color: GamyaColors.textSecondary))])])),
    SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _BarsPainter(groups, colors, barWidthFactor, showValues))),
  ]);
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.groups, this.colors, this.wf, this.showValues);
  final List<BarGroup> groups; final List<Color> colors; final double wf; final bool showValues;
  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 30.0, bottomPad = 22.0, topPad = 8.0;
    final maxV = math.max(1, groups.fold<num>(0, (m, g) => math.max(m, g.total))).toDouble();
    final niceMax = _nice(maxV);
    final plotH = size.height - bottomPad - topPad; final plotW = size.width - leftPad;
    final grid = Paint()..color = GamyaColors.divider..strokeWidth = 1;
    TextPainter tp(String s, {TextAlign align = TextAlign.right, Color c = GamyaColors.textMuted}) => TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: 10, color: c)), textDirection: TextDirection.ltr, textAlign: align)..layout();
    for (var i = 0; i <= 5; i++) {
      final y = topPad + plotH - plotH * i / 5;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), grid);
      final t = tp('${(niceMax * i / 5).round()}'); t.paint(canvas, Offset(leftPad - 6 - t.width, y - t.height / 2));
    }
    if (groups.isEmpty) return;
    final slot = plotW / groups.length; final bw = slot * wf;
    for (var gi = 0; gi < groups.length; gi++) {
      final g = groups[gi]; final x = leftPad + slot * gi + (slot - bw) / 2;
      var yTop = topPad + plotH;
      for (var vi = 0; vi < g.values.length; vi++) {
        final h = plotH * g.values[vi] / niceMax;
        final r = Rect.fromLTWH(x, yTop - h, bw, h);
        canvas.drawRRect(RRect.fromRectAndCorners(r, topLeft: Radius.circular(vi == g.values.length - 1 ? 3 : 0), topRight: Radius.circular(vi == g.values.length - 1 ? 3 : 0)), Paint()..color = colors[vi % colors.length]);
        yTop -= h;
      }
      if (showValues && g.total > 0) { final t = tp('${g.total}', c: GamyaColors.textPrimary); t.paint(canvas, Offset(x + bw / 2 - t.width / 2, yTop - t.height - 2)); }
      final l = tp(g.label, align: TextAlign.center); l.paint(canvas, Offset(x + bw / 2 - l.width / 2, size.height - bottomPad + 6));
    }
  }
  double _nice(double v) { if (v <= 5) return 5; final m = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble(); final f = v / m; final n = f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10; return n * m; }
  @override
  bool shouldRepaint(covariant _BarsPainter o) => o.groups != groups;
}

class LineSeries {
  const LineSeries({required this.label, required this.values, required this.color});
  final String label; final List<num> values; final Color color;
}

/// Multi-series line chart with dots (Bookings Trend, Ad-hoc Trends).
class LineChart extends StatelessWidget {
  const LineChart({super.key, required this.labels, required this.series, this.height = 170, this.fill = false});
  final List<String> labels; final List<LineSeries> series; final double height; final bool fill;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (series.length > 1) Padding(padding: const EdgeInsets.only(bottom: 8), child: Wrap(spacing: 14, children: [for (final s in series) Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: s.color), const SizedBox(width: 5), Text(s.label, style: const TextStyle(fontSize: 11.5, color: GamyaColors.textSecondary))])])),
    SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _LinePainter(labels, series, fill))),
  ]);
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.labels, this.series, this.fill);
  final List<String> labels; final List<LineSeries> series; final bool fill;
  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 30.0, bottomPad = 22.0, topPad = 8.0;
    final maxV = math.max(1, series.fold<num>(0, (m, s) => math.max(m, s.values.isEmpty ? 0 : s.values.reduce(math.max)))).toDouble();
    final niceMax = maxV <= 5 ? 5.0 : (maxV / 5).ceil() * 5.0;
    final plotH = size.height - bottomPad - topPad; final plotW = size.width - leftPad;
    final grid = Paint()..color = GamyaColors.divider..strokeWidth = 1;
    TextPainter tp(String s) => TextPainter(text: TextSpan(text: s, style: const TextStyle(fontSize: 10, color: GamyaColors.textMuted)), textDirection: TextDirection.ltr)..layout();
    for (var i = 0; i <= 5; i++) { final y = topPad + plotH - plotH * i / 5; canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), grid); final t = tp('${(niceMax * i / 5).round()}'); t.paint(canvas, Offset(leftPad - 6 - t.width, y - t.height / 2)); }
    final n = labels.length; if (n == 0) return;
    final step = n == 1 ? 0 : plotW / (n - 1);
    final every = math.max(1, (n / (plotW / 46)).ceil());
    for (var i = 0; i < n; i += every) { final t = tp(labels[i]); t.paint(canvas, Offset(leftPad + step * i - t.width / 2, size.height - bottomPad + 6)); }
    for (final s in series) {
      final path = Path(); final pts = <Offset>[];
      for (var i = 0; i < math.min(n, s.values.length); i++) {
        final p = Offset(leftPad + step * i, topPad + plotH - plotH * s.values[i] / niceMax); pts.add(p);
        if (i == 0) { path.moveTo(p.dx, p.dy); } else { path.lineTo(p.dx, p.dy); }
      }
      if (fill && pts.isNotEmpty) { final f = Path.from(path)..lineTo(pts.last.dx, topPad + plotH)..lineTo(pts.first.dx, topPad + plotH)..close(); canvas.drawPath(f, Paint()..color = s.color.withValues(alpha: 0.12)); }
      canvas.drawPath(path, Paint()..color = s.color..style = PaintingStyle.stroke..strokeWidth = 2..strokeJoin = StrokeJoin.round);
      for (final p in pts) { canvas.drawCircle(p, 3.2, Paint()..color = Colors.white); canvas.drawCircle(p, 3.2, Paint()..color = s.color..style = PaintingStyle.stroke..strokeWidth = 1.8); }
    }
  }
  @override
  bool shouldRepaint(covariant _LinePainter o) => o.series != series || o.labels != labels;
}

/// Horizontal bars with label + value at the right (Top clients, Vehicle type wise).
class HBarList extends StatelessWidget {
  const HBarList({super.key, required this.items, this.color = GamyaColors.info, this.labelWidth = 90, this.colors});
  final List<ChartSlice> items; final Color color; final double labelWidth; final List<Color>? colors;
  @override
  Widget build(BuildContext context) {
    final max = items.fold<num>(1, (m, i) => math.max(m, i.value));
    return Column(children: [
      for (var i = 0; i < items.length; i++) Padding(padding: const EdgeInsets.symmetric(vertical: 3.5), child: Row(children: [
        SizedBox(width: labelWidth, child: Text(items[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: items[i].value / max, minHeight: 9, backgroundColor: GamyaColors.neutralBg, color: colors != null ? colors![i % colors!.length] : items[i].color))),
        const SizedBox(width: 10), SizedBox(width: 34, child: Text('${items[i].value}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
      ])),
    ]);
  }
}
