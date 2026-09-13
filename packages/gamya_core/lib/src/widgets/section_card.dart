import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// White card with a title row and optional trailing action ("View All").
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(16), this.headerPadding, this.minHeight});
  final String? title; final Widget? trailing; final Widget child; final EdgeInsets padding; final EdgeInsets? headerPadding; final double? minHeight;
  @override
  Widget build(BuildContext context) => Card(
    child: ConstrainedBox(constraints: BoxConstraints(minHeight: minHeight ?? 0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (title != null) Padding(padding: headerPadding ?? EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 8), child: Row(children: [Expanded(child: Text(title!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))), if (trailing != null) trailing!])),
      Padding(padding: title != null ? EdgeInsets.fromLTRB(padding.left, 4, padding.right, padding.bottom) : padding, child: child),
    ])),
  );
}

class ViewAllLink extends StatelessWidget {
  const ViewAllLink({super.key, this.onTap, this.label = 'View All'});
  final VoidCallback? onTap; final String label;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Text(label, style: const TextStyle(color: GamyaColors.info, fontSize: 12.5, fontWeight: FontWeight.w600)));
}

/// Key : Value rows used in detail panels.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.valueWidget, this.labelWidth = 130, this.icon});
  final String label; final String? value; final Widget? valueWidget; final double labelWidth; final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (icon != null) ...[Icon(icon, size: 15, color: GamyaColors.textMuted), const SizedBox(width: 8)],
      SizedBox(width: labelWidth, child: Text(label, style: const TextStyle(fontSize: 12.5, color: GamyaColors.textSecondary))),
      const Text(':  ', style: TextStyle(fontSize: 12.5, color: GamyaColors.textSecondary)),
      Expanded(child: valueWidget ?? Text(value == null || value!.isEmpty ? '—' : value!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: GamyaColors.textPrimary))),
    ]),
  );
}

/// Pill tab row ("All (42) | Active (38) | Inactive (4)").
class PillTabs extends StatelessWidget {
  const PillTabs({super.key, required this.tabs, required this.selected, required this.onChanged});
  final List<String> tabs; final int selected; final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: GamyaColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: GamyaColors.border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < tabs.length; i++) InkWell(borderRadius: BorderRadius.circular(6), onTap: () => onChanged(i), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(color: i == selected ? GamyaColors.gold : Colors.transparent, borderRadius: BorderRadius.circular(6)), child: Text(tabs[i], style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: i == selected ? Colors.white : GamyaColors.textSecondary))))]),
  );
}
