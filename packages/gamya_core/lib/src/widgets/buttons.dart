import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Primary gold button with optional icon and loading state.
class GoldButton extends StatelessWidget {
  const GoldButton({super.key, required this.label, this.onPressed, this.icon, this.loading = false, this.expand = false, this.dense = false, this.color});
  final String label; final VoidCallback? onPressed; final IconData? icon; final bool loading; final bool expand; final bool dense; final Color? color;
  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)], Text(label)]);
    final btn = FilledButton(onPressed: loading ? null : onPressed, style: FilledButton.styleFrom(backgroundColor: color ?? GamyaColors.gold, disabledBackgroundColor: (color ?? GamyaColors.gold).withValues(alpha: 0.6), padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 20, vertical: dense ? 10 : 14)), child: child);
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class OutlineButton extends StatelessWidget {
  const OutlineButton({super.key, required this.label, this.onPressed, this.icon, this.color, this.expand = false, this.dense = false, this.loading = false});
  final String label; final VoidCallback? onPressed; final IconData? icon; final Color? color; final bool expand; final bool dense; final bool loading;
  @override
  Widget build(BuildContext context) {
    final c = color ?? GamyaColors.textPrimary;
    final btn = OutlinedButton(onPressed: loading ? null : onPressed, style: OutlinedButton.styleFrom(foregroundColor: c, side: BorderSide(color: color ?? GamyaColors.border), padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 18, vertical: dense ? 10 : 14)), child: loading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c)) : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)], Text(label)]));
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Small icon button used in table action columns.
class TableIconButton extends StatelessWidget {
  const TableIconButton({super.key, required this.icon, this.onPressed, this.tooltip, this.color});
  final IconData icon; final VoidCallback? onPressed; final String? tooltip; final Color? color;
  @override
  Widget build(BuildContext context) => IconButton(onPressed: onPressed, tooltip: tooltip, icon: Icon(icon, size: 17, color: color ?? GamyaColors.textSecondary), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30), style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: const BorderSide(color: GamyaColors.border))));
}
