import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Search box with leading icon, used in top bars and filter rows.
class SearchField extends StatelessWidget {
  const SearchField({super.key, this.controller, this.hint = 'Search…', this.onSubmitted, this.onChanged, this.dark = false, this.width});
  final TextEditingController? controller; final String hint; final ValueChanged<String>? onSubmitted; final ValueChanged<String>? onChanged; final bool dark; final double? width;
  @override
  Widget build(BuildContext context) {
    final f = TextField(
      controller: controller, onSubmitted: onSubmitted, onChanged: onChanged, style: TextStyle(fontSize: 13.5, color: dark ? Colors.white : GamyaColors.textPrimary),
      decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(fontSize: 13, color: dark ? Colors.white54 : GamyaColors.textMuted), prefixIcon: Icon(Icons.search, size: 19, color: dark ? Colors.white70 : GamyaColors.textMuted), filled: true, fillColor: dark ? Colors.white.withValues(alpha: 0.08) : Colors.white, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: dark ? Colors.white24 : GamyaColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GamyaColors.gold)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
    );
    return width == null ? f : SizedBox(width: width, child: f);
  }
}

/// Compact filter dropdown ("All Status ▾").
class FilterDropdown<T> extends StatelessWidget {
  const FilterDropdown({super.key, required this.label, required this.value, required this.items, required this.onChanged, this.width = 150});
  final String label; final T? value; final List<DropdownMenuItem<T?>> items; final ValueChanged<T?> onChanged; final double width;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: DropdownButtonFormField<T?>(
    key: ValueKey(value), initialValue: value, isDense: true, isExpanded: true, style: const TextStyle(fontSize: 12.5, color: GamyaColors.textPrimary), icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: GamyaColors.textMuted),
    decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GamyaColors.border))),
    hint: Text(label, style: const TextStyle(fontSize: 12.5, color: GamyaColors.textPrimary)), items: [DropdownMenuItem<T?>(value: null, child: Text(label, style: const TextStyle(fontSize: 12.5))), ...items], onChanged: onChanged,
  ));
}

/// Labelled form field used on mobile forms and dialogs.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child, this.required = false});
  final String label; final Widget child; final bool required;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(bottom: 6), child: RichText(text: TextSpan(text: label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: GamyaColors.textPrimary), children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: GamyaColors.danger))]))),
    child, const SizedBox(height: 14),
  ]);
}

/// − 1 + stepper.
class Stepper2 extends StatelessWidget {
  const Stepper2({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 20});
  final int value; final ValueChanged<int> onChanged; final int min; final int max;
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(border: Border.all(color: GamyaColors.border), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [
    IconButton(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove, size: 18), constraints: const BoxConstraints(minWidth: 40, minHeight: 40), padding: EdgeInsets.zero),
    SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
    IconButton(onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add, size: 18), constraints: const BoxConstraints(minWidth: 40, minHeight: 40), padding: EdgeInsets.zero),
  ]));
}

/// Radio-style option tile (used for Instant / Scheduled and platform picker).
class OptionTile extends StatelessWidget {
  const OptionTile({super.key, required this.selected, required this.onTap, required this.title, this.subtitle, this.leading});
  final bool selected; final VoidCallback onTap; final String title; final String? subtitle; final Widget? leading;
  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: selected ? GamyaColors.goldPale : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? GamyaColors.gold : GamyaColors.border, width: selected ? 1.5 : 1)),
    child: Row(children: [if (leading != null) ...[leading!, const SizedBox(width: 12)], Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))])), Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? GamyaColors.gold : GamyaColors.textMuted)]),
  ));
}
