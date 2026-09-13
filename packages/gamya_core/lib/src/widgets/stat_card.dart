import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Dashboard stat card: icon tile, label, big value and a trend line.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.icon, this.iconColor = GamyaColors.gold, this.trend, this.trendPositive, this.trendIcon, this.trendColor, this.onTap, this.dense = false});
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? trend;
  final bool? trendPositive;
  final IconData? trendIcon;
  final Color? trendColor;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tc = trendColor ?? (trendPositive == null ? GamyaColors.warning : trendPositive! ? GamyaColors.success : GamyaColors.danger);
    final ti = trendIcon ?? (trendPositive == null ? Icons.schedule : trendPositive! ? Icons.arrow_upward : Icons.arrow_downward);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12), onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(dense ? 12 : 16),
          child: Row(children: [
            Container(width: dense ? 40 : 48, height: dense ? 40 : 48, decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: dense ? 22 : 26)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: dense ? 20 : 24, fontWeight: FontWeight.w700, color: GamyaColors.textPrimary, height: 1.1)),
              if (trend != null) ...[const SizedBox(height: 4), Row(children: [Icon(ti, size: 12, color: tc), const SizedBox(width: 3), Flexible(child: Text(trend!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: tc, fontWeight: FontWeight.w500)))])],
            ])),
          ]),
        ),
      ),
    );
  }
}

/// Small counter tile (e.g. "Today's Bookings 5").
class MiniStat extends StatelessWidget {
  const MiniStat({super.key, required this.label, required this.value, this.icon, this.color});
  final String label; final String value; final IconData? icon; final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: GamyaColors.border)),
    child: Row(children: [
      if (icon != null) ...[Icon(icon, size: 18, color: color ?? GamyaColors.gold), const SizedBox(width: 8)],
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: GamyaColors.textSecondary)), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))])),
    ]),
  );
}
